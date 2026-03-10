use super::*;
use serial_test::serial;

fn zebra_schema() -> Value {
    json!({
        "openrpc": "1.2.6",
        "methods": [
            { "name": "getblock", "params": [] },
            { "name": "getinfo",  "params": [] }
        ],
        "components": {
            "schemas": {
                "BlockHash": { "type": "string" }
            }
        }
    })
}

fn zallet_schema() -> Value {
    json!({
        "openrpc": "1.2.6",
        "methods": [
            { "name": "getwalletinfo", "params": [] },
            { "name": "z_sendmany",    "params": [] }
        ],
        "components": {
            "schemas": {
                "WalletInfo": { "type": "object" }
            }
        }
    })
}

// --- extract_methods_array ---

#[test]
fn test_extract_methods_array_returns_methods() {
    let schema = zebra_schema();
    let methods = extract_methods_array(&schema);
    assert_eq!(methods.len(), 2);
    assert_eq!(methods[0]["name"], "getblock");
    assert_eq!(methods[1]["name"], "getinfo");
}

#[test]
fn test_extract_methods_array_missing_key_returns_empty() {
    let schema = json!({ "openrpc": "1.2.6" });
    let methods = extract_methods_array(&schema);
    assert!(methods.is_empty());
}

// --- annotate_methods_with_server ---

#[test]
fn test_annotate_methods_sets_x_server() {
    let mut methods = extract_methods_array(&zebra_schema());
    annotate_methods_with_server(&mut methods, "zebra");
    for m in &methods {
        assert_eq!(m["x-server"], "zebra");
    }
}

#[test]
fn test_annotate_methods_non_object_entry_does_not_panic() {
    // A schema that contains a non-object method entry (e.g. a bare string).
    let schema = json!({ "methods": ["not-an-object", { "name": "getblock" }] });
    let mut methods = extract_methods_array(&schema);
    // Must not panic — the non-object entry is silently skipped.
    annotate_methods_with_server(&mut methods, "zebra");
    assert_eq!(methods[1]["x-server"], "zebra");
}

// --- merge_components_schemas ---

#[test]
fn test_merge_components_schemas_combines_keys() {
    let mut combined = serde_json::Map::new();
    merge_components_schemas(&zebra_schema(), &mut combined);
    merge_components_schemas(&zallet_schema(), &mut combined);
    assert!(combined.contains_key("BlockHash"));
    assert!(combined.contains_key("WalletInfo"));
}

#[test]
fn test_merge_components_schemas_missing_components_is_noop() {
    let schema = json!({ "methods": [] });
    let mut combined = serde_json::Map::new();
    merge_components_schemas(&schema, &mut combined);
    assert!(combined.is_empty());
}

#[test]
fn test_merge_components_schemas_last_write_wins_on_conflict() {
    let schema_a = json!({ "components": { "schemas": { "Foo": { "type": "string" } } } });
    let schema_b = json!({ "components": { "schemas": { "Foo": { "type": "integer" } } } });
    let mut combined = serde_json::Map::new();
    merge_components_schemas(&schema_a, &mut combined);
    merge_components_schemas(&schema_b, &mut combined);
    assert_eq!(combined["Foo"]["type"], "integer");
}

// --- merge_openrpc_schemas ---

#[test]
fn test_merge_openrpc_schemas_combined_method_count() {
    let z3 = merge_openrpc_schemas(zebra_schema(), zallet_schema()).unwrap();
    assert_eq!(z3.zebra_methods.len(), 2);
    assert_eq!(z3.zallet_methods.len(), 2);
    assert_eq!(z3.merged["methods"].as_array().unwrap().len(), 4);
}

#[test]
fn test_merge_openrpc_schemas_methods_annotated() {
    let z3 = merge_openrpc_schemas(zebra_schema(), zallet_schema()).unwrap();
    for m in &z3.zebra_methods {
        assert_eq!(m["x-server"], "zebra");
    }
    for m in &z3.zallet_methods {
        assert_eq!(m["x-server"], "zallet");
    }
}

#[test]
fn test_merge_openrpc_schemas_components_merged() {
    let z3 = merge_openrpc_schemas(zebra_schema(), zallet_schema()).unwrap();
    let schemas = &z3.merged["components"]["schemas"];
    assert!(schemas.get("BlockHash").is_some());
    assert!(schemas.get("WalletInfo").is_some());
}

#[test]
fn test_merge_openrpc_schemas_info_fields_present() {
    let z3 = merge_openrpc_schemas(zebra_schema(), zallet_schema()).unwrap();
    assert!(z3.merged["info"]["title"].is_string());
    assert!(z3.merged["info"]["version"].is_string());
}

// --- Config::from_env ---

#[test]
#[serial]
fn test_config_from_env_uses_defaults() {
    env::remove_var("RPC_USER");
    env::remove_var("RPC_PASSWORD");
    let config = Config::from_env();
    assert_eq!(config.rpc_user, "zebra");
    assert_eq!(config.rpc_password, "zebra");
}

#[test]
#[serial]
fn test_config_from_env_reads_rpc_credentials() {
    env::set_var("RPC_USER", "alice");
    env::set_var("RPC_PASSWORD", "s3cr3t");
    let config = Config::from_env();
    assert_eq!(config.rpc_user, "alice");
    assert_eq!(config.rpc_password, "s3cr3t");
    env::remove_var("RPC_USER");
    env::remove_var("RPC_PASSWORD");
}
