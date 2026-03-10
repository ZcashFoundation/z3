use httpmock::prelude::*;
use reqwest::Client;
use serde_json::{json, Value};
use std::sync::Arc;
use tokio::net::TcpListener;

use super::*;

// --- Mock backend helpers ---

/// Starts a mock Zebra backend that handles rpc.discover and method forwarding.
/// Returns a distinct "zebra-response" result so routing can be verified.
async fn start_zebra_mock() -> MockServer {
    let server = MockServer::start_async().await;

    server
        .mock_async(|when, then| {
            when.method(POST).body_contains("rpc.discover");
            then.status(200).json_body(json!({
                "jsonrpc": "2.0", "id": 1,
                "result": {
                    "openrpc": "1.2.6",
                    "info": { "title": "Zebra", "version": "1.0.0" },
                    "methods": [
                        { "name": "getblock",  "params": [] },
                        { "name": "getinfo",   "params": [] }
                    ],
                    "components": { "schemas": { "BlockHash": { "type": "string" } } }
                }
            }));
        })
        .await;

    server
        .mock_async(|when, then| {
            when.method(POST);
            then.status(200)
                .json_body(json!({ "jsonrpc": "2.0", "id": 1, "result": "zebra-response" }));
        })
        .await;

    server
}

/// Starts a mock Zallet backend that handles rpc.discover and method forwarding.
async fn start_zallet_mock() -> MockServer {
    let server = MockServer::start_async().await;

    server
        .mock_async(|when, then| {
            when.method(POST).body_contains("rpc.discover");
            then.status(200).json_body(json!({
                "jsonrpc": "2.0", "id": 1,
                "result": {
                    "openrpc": "1.2.6",
                    "info": { "title": "Zallet", "version": "1.0.0" },
                    "methods": [
                        { "name": "getwalletinfo", "params": [] },
                        { "name": "z_sendmany",    "params": [] }
                    ],
                    "components": { "schemas": { "WalletInfo": { "type": "object" } } }
                }
            }));
        })
        .await;

    server
        .mock_async(|when, then| {
            when.method(POST);
            then.status(200)
                .json_body(json!({ "jsonrpc": "2.0", "id": 1, "result": "zallet-response" }));
        })
        .await;

    server
}

/// Starts a mock Zaino backend (generic fallback).
async fn start_zaino_mock() -> MockServer {
    let server = MockServer::start_async().await;

    server
        .mock_async(|when, then| {
            when.method(POST);
            then.status(200)
                .json_body(json!({ "jsonrpc": "2.0", "id": 1, "result": "zaino-response" }));
        })
        .await;

    server
}

// --- Router startup helper ---

struct RouterHandle {
    pub port: u16,
    task: tokio::task::JoinHandle<()>,
}

impl Drop for RouterHandle {
    fn drop(&mut self) {
        self.task.abort();
    }
}

async fn start_router(zebra_url: &str, zallet_url: &str, zaino_url: &str) -> RouterHandle {
    let config = Arc::new(Config {
        zebra_url: zebra_url.to_string(),
        zallet_url: zallet_url.to_string(),
        _zaino_url: zaino_url.to_string(),
        listen_port: 0,
        rpc_user: "zebra".to_string(),
        rpc_password: "zebra".to_string(),
        cors_origin: "*".to_string(),
    });

    let zebra_schema = call_rpc_discover(&config.zebra_url, &config.rpc_user, &config.rpc_password)
        .await
        .unwrap()["result"]
        .clone();
    let zallet_schema =
        call_rpc_discover(&config.zallet_url, &config.rpc_user, &config.rpc_password)
            .await
            .unwrap()["result"]
            .clone();
    let z3 = merge_openrpc_schemas(zebra_schema, zallet_schema).unwrap();

    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();

    let task = tokio::spawn(async move {
        if let Err(e) = run(config, listener, z3).await {
            eprintln!("Router error in test: {}", e);
        }
    });

    // Let the router start accepting connections.
    tokio::time::sleep(std::time::Duration::from_millis(10)).await;

    RouterHandle { port, task }
}

// --- Tests ---

#[tokio::test]
async fn test_health_check() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .get(format!("http://127.0.0.1:{}/health", router.port))
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 200);
    assert_eq!(resp.text().await.unwrap(), "OK");
}

#[tokio::test]
async fn test_non_post_returns_405() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .get(format!("http://127.0.0.1:{}/", router.port))
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 405);
}

#[tokio::test]
async fn test_cors_preflight_returns_204_with_headers() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .request(
            reqwest::Method::OPTIONS,
            format!("http://127.0.0.1:{}/", router.port),
        )
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 204);
    assert!(resp.headers().contains_key("access-control-allow-origin"));
    assert!(resp.headers().contains_key("access-control-allow-methods"));
}

#[tokio::test]
async fn test_rpc_discover_returns_merged_schema() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .post(format!("http://127.0.0.1:{}/", router.port))
        .json(&json!({ "jsonrpc": "2.0", "id": 1, "method": "rpc.discover", "params": [] }))
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 200);

    let body: Value = resp.json().await.unwrap();
    let methods = body["methods"].as_array().unwrap();
    let names: Vec<&str> = methods
        .iter()
        .map(|m| m["name"].as_str().unwrap())
        .collect();

    assert!(names.contains(&"getblock"));
    assert!(names.contains(&"getinfo"));
    assert!(names.contains(&"getwalletinfo"));
    assert!(names.contains(&"z_sendmany"));
}

#[tokio::test]
async fn test_zebra_method_routing() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .post(format!("http://127.0.0.1:{}/", router.port))
        .json(&json!({ "jsonrpc": "2.0", "id": 1, "method": "getblock", "params": [] }))
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 200);
    let body: Value = resp.json().await.unwrap();
    assert_eq!(body["result"], "zebra-response");
}

#[tokio::test]
async fn test_zallet_method_routing() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .post(format!("http://127.0.0.1:{}/", router.port))
        .json(&json!({ "jsonrpc": "2.0", "id": 1, "method": "getwalletinfo", "params": [] }))
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 200);
    let body: Value = resp.json().await.unwrap();
    assert_eq!(body["result"], "zallet-response");
}

#[tokio::test]
async fn test_unknown_method_falls_back_to_zebra() {
    let zebra = start_zebra_mock().await;
    let zallet = start_zallet_mock().await;
    let zaino = start_zaino_mock().await;
    let router = start_router(&zebra.base_url(), &zallet.base_url(), &zaino.base_url()).await;

    let resp = Client::new()
        .post(format!("http://127.0.0.1:{}/", router.port))
        .json(
            &json!({ "jsonrpc": "2.0", "id": 1, "method": "z_getaddressforaccount", "params": [] }),
        )
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), 200);
    let body: Value = resp.json().await.unwrap();
    assert_eq!(body["result"], "zebra-response");
}
