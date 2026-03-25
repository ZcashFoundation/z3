//! RPC Router for Zebra, Zallet and Zaino.
//!
//! This service listens for JSON-RPC requests and routes them to the appropriate backend
//! based on the method being called. It merges the OpenRPC schemas from Zebra and Zallet
//! to determine which methods belong to which service.
use std::{env, net::SocketAddr, sync::Arc};


use anyhow::Result;
use base64::{engine::general_purpose, Engine as _};
use http_body_util::{BodyExt, Full};
use hyper::{
    body::Bytes,
    header::{HeaderName, HeaderValue},
    server::conn::http1,
    service::service_fn,
    Request, Response, StatusCode, Uri,
};
use hyper_util::{
    client::legacy::Client as HyperClient,
    rt::{TokioExecutor, TokioIo},
};
use reqwest::Client as ReqwestClient;
use serde::Deserialize;
use serde_json::{json, Value};
use tokio::net::TcpListener;
use tracing::{error, info, warn};

mod defaults;

#[cfg(test)]
mod unit_tests;

#[cfg(test)]
mod integration_tests;

/// Structure to parse incoming JSON-RPC requests.
#[derive(Deserialize, Debug)]
struct RpcRequest {
    method: String,
}

/// Configuration for the RPC router.
#[derive(Clone)]
struct Config {
    zebra_url: String,
    zallet_url: String,
    _zaino_url: String,
    rpc_user: String,
    rpc_password: String,
    cors_origin: String,
    listen_port: u16,
}

impl Config {
    fn from_env() -> Self {
        Self {
            zebra_url: env::var("ZEBRA_URL")
                .unwrap_or_else(|_| defaults::ZEBRA_URL.to_string()),
            zallet_url: env::var("ZALLET_URL")
                .unwrap_or_else(|_| defaults::ZALLET_URL.to_string()),
            _zaino_url: env::var("ZAINO_URL").unwrap_or_else(|_| defaults::ZAINO_URL.to_string()),
            rpc_user: env::var("RPC_USER").unwrap_or_else(|_| defaults::RPC_USER.to_string()),
            rpc_password: env::var("RPC_PASSWORD").unwrap_or_else(|_| defaults::RPC_PASSWORD.to_string()),
            cors_origin: env::var("CORS_ORIGIN")
                .unwrap_or_else(|_| defaults::CORS_ORIGIN.to_string()),
            listen_port: env::var("LISTEN_PORT")
                .ok()
                .and_then(|p| p.parse().ok())
                .unwrap_or(defaults::LISTEN_PORT),
        }
    }
}

/// Merged schema and method lists for routing.
#[derive(Clone)]
struct Z3Schema {
    zebra_methods: Vec<Value>,
    zallet_methods: Vec<Value>,
    merged: Value,
}

/// Forwards the incoming request to the specified target URL with basic auth.
async fn forward_request(
    req: Request<Full<Bytes>>,
    target_url: &str,
    rpc_user: &str,
    rpc_password: &str,
) -> Result<Response<Full<Bytes>>> {
    let client = HyperClient::builder(TokioExecutor::new()).build_http();

    let uri_string = format!(
        "{}{}",
        target_url,
        req.uri()
            .path_and_query()
            .map(|x| x.as_str())
            .unwrap_or("/")
    );
    let uri: Uri = uri_string.parse()?;

    let (parts, body) = req.into_parts();
    let mut new_req = Request::builder()
        .method(parts.method)
        .uri(uri)
        .version(parts.version);

    // Inject auth header
    let auth = general_purpose::STANDARD.encode(format!("{}:{}", rpc_user, rpc_password));
    new_req = new_req.header(
        hyper::header::AUTHORIZATION,
        hyper::header::HeaderValue::from_str(&format!("Basic {}", auth))?,
    );

    // Copy other headers
    for (k, v) in parts.headers {
        if let Some(key) = k {
            new_req = new_req.header(key, v);
        }
    }

    let new_req = new_req.body(body)?;
    let res = client.request(new_req).await?;

    let (parts, body) = res.into_parts();
    let body_bytes = body.collect().await?.to_bytes();
    let new_res = Response::from_parts(parts, Full::new(body_bytes));

    Ok(new_res)
}

/// Adds CORS headers to the response.
fn add_cors_headers(mut resp: Response<Full<Bytes>>, cors_origin: &str) -> Response<Full<Bytes>> {
    let headers = resp.headers_mut();
    headers.insert(
        HeaderName::from_static("access-control-allow-origin"),
        HeaderValue::from_str(cors_origin).unwrap_or(HeaderValue::from_static("*")),
    );
    for &(name, value) in &[
        ("access-control-allow-methods", "POST, OPTIONS"),
        ("access-control-allow-headers", "Content-Type"),
        ("access-control-max-age", "86400"),
    ] {
        headers.insert(
            HeaderName::from_static(name),
            HeaderValue::from_static(value),
        );
    }

    resp
}

/// Main request handler.
async fn handler(
    req: Request<hyper::body::Incoming>,
    config: Arc<Config>,
    z3: Z3Schema,
) -> Result<Response<Full<Bytes>>> {
    // Health check
    if req.uri().path() == "/health" {
        return Ok(Response::new(Full::new(Bytes::from("OK"))));
    }

    // Handle CORS preflight
    if req.method() == hyper::Method::OPTIONS {
        let resp = add_cors_headers(
            Response::builder()
                .status(StatusCode::NO_CONTENT)
                .body(Full::new(Bytes::new()))
                .unwrap(),
            &config.cors_origin,
        );
        return Ok(resp);
    }

    // Only handle POST requests for JSON-RPC
    if req.method() != hyper::Method::POST {
        return Ok(Response::builder()
            .status(StatusCode::METHOD_NOT_ALLOWED)
            .body(Full::new(Bytes::from("Method Not Allowed")))
            .unwrap());
    }

    // Buffer the body to parse it
    let (parts, body) = req.into_parts();
    let body_bytes = body.collect().await?.to_bytes();

    // Attempt to parse method from body
    let target_url = if let Ok(rpc_req) = serde_json::from_slice::<RpcRequest>(&body_bytes) {
        if rpc_req.method == "rpc.discover" {
            info!("Routing rpc.discover to merged schema");

            return Ok(add_cors_headers(
                Response::builder()
                    .status(StatusCode::OK)
                    .header(hyper::header::CONTENT_TYPE, "application/json")
                    .body(Full::new(Bytes::from(serde_json::to_string(&z3.merged)?)))
                    .expect("z3 merged schema response should be valid"),
                &config.cors_origin,
            ));
        }

        if z3.zebra_methods.iter().any(|m| m["name"] == rpc_req.method) {
            info!("Routing {} to Zebra", rpc_req.method);
            &config.zebra_url
        } else if z3
            .zallet_methods
            .iter()
            .any(|m| m["name"] == rpc_req.method)
        {
            info!("Routing {} to Zallet", rpc_req.method);
            &config.zallet_url
        } else {
            warn!(
                "Method '{}' not found in Zebra or Zallet schema, falling back to Zebra",
                rpc_req.method
            );
            &config.zebra_url
        }
    } else {
        warn!("Failed to parse JSON-RPC body, defaulting to Zebra");
        &config.zebra_url
    };

    // Reconstruct request with buffered body
    let new_req = Request::from_parts(parts, Full::new(body_bytes));

    match forward_request(new_req, target_url, &config.rpc_user, &config.rpc_password).await {
        Ok(res) => Ok(add_cors_headers(res, &config.cors_origin)),
        Err(e) => {
            error!("Forwarding error: {}", e);

            Ok(Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(Full::new(Bytes::from(format!("Bad Gateway: {}", e))))
                .unwrap())
        }
    }
}

/// Calls rpc.discover on the given URL and returns the parsed JSON response.
async fn call_rpc_discover(
    url: &str,
    rpc_user: &str,
    rpc_password: &str,
) -> Result<serde_json::Value> {
    let client = ReqwestClient::new();

    let body = json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "rpc.discover",
        "params": []
    });

    let text = client
        .post(url)
        .basic_auth(rpc_user, Some(rpc_password))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(body.to_string())
        .send()
        .await?
        .error_for_status()?
        .text()
        .await?;

    let resp = serde_json::from_str::<serde_json::Value>(&text)?;

    Ok(resp)
}

/// Extracts the methods array from the OpenRPC schema.
fn extract_methods_array(schema: &Value) -> Vec<Value> {
    schema["methods"].as_array().cloned().unwrap_or_default()
}

/// Annotates each method with its origin server.
fn annotate_methods_with_server(methods: &mut Vec<Value>, server_name: &str) {
    for m in methods {
        if let Some(obj) = m.as_object_mut() {
            obj.insert("x-server".to_string(), json!(server_name));
        } else {
            warn!(
                "Skipping non-object method entry while annotating for {}",
                server_name
            );
        }
    }
}

/// Merges the components.schemas from the given schema into the combined map.
fn merge_components_schemas(schema: &Value, combined: &mut serde_json::Map<String, Value>) {
    if let Some(obj) = schema["components"]["schemas"].as_object() {
        for (k, v) in obj {
            combined.insert(k.clone(), v.clone());
        }
    }
}

/// Merges the OpenRPC schemas from Zebra and Zallet.
fn merge_openrpc_schemas(zebra: Value, zallet: Value) -> Result<Z3Schema> {
    // Extract method arrays
    let mut zebra_methods = extract_methods_array(&zebra);
    let mut zallet_methods = extract_methods_array(&zallet);

    // Annotate each method with its origin
    annotate_methods_with_server(&mut zebra_methods, "zebra");
    annotate_methods_with_server(&mut zallet_methods, "zallet");

    // Merge schemas under components.schemas
    let mut combined_schemas = serde_json::Map::new();
    merge_components_schemas(&zebra, &mut combined_schemas);
    merge_components_schemas(&zallet, &mut combined_schemas);

    let mut combined_methods = Vec::new();
    combined_methods.extend(zebra_methods.clone());
    combined_methods.extend(zallet_methods.clone());

    // Build final merged schema
    let merged = json!({
        "openrpc": zebra["openrpc"].clone(),
        "info": {
            "title":  env!("CARGO_PKG_NAME"),
            "description": env!("CARGO_PKG_DESCRIPTION"),
            "version": env!("CARGO_PKG_VERSION"),
        },
        "servers": [
            { "name": "router",  "url": "http://localhost:8080/" },
        ],
        "methods": combined_methods,
        "components": {
            "schemas": combined_schemas
        }
    });

    let z3 = Z3Schema {
        zebra_methods,
        zallet_methods,
        merged,
    };

    Ok(z3)
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let config = Arc::new(Config::from_env());
    let addr = SocketAddr::from(([0, 0, 0, 0], config.listen_port));

    let zebra_schema = call_rpc_discover(&config.zebra_url, &config.rpc_user, &config.rpc_password)
        .await?["result"]
        .clone();
    let zallet_schema =
        call_rpc_discover(&config.zallet_url, &config.rpc_user, &config.rpc_password).await?
            ["result"]
            .clone();

    let z3 = merge_openrpc_schemas(zebra_schema, zallet_schema)?;

    let listener = TcpListener::bind(addr).await?;
    info!("RPC Router listening on {}", addr);
    info!("You can use the following playground URL:");
    info!("{}", defaults::playground_url(addr));

    run(config, listener, z3).await
}

/// Accepts connections and dispatches requests. Extracted for testability.
async fn run(config: Arc<Config>, listener: TcpListener, z3: Z3Schema) -> Result<()> {
    loop {
        let (stream, _) = listener.accept().await?;
        let io = TokioIo::new(stream);
        let config = config.clone();

        let z3 = z3.clone();
        tokio::task::spawn(async move {
            if let Err(err) = http1::Builder::new()
                .serve_connection(
                    io,
                    service_fn(move |req| handler(req, config.clone(), z3.clone())),
                )
                .await
            {
                error!("Error serving connection: {:?}", err);
            }
        });
    }
}
