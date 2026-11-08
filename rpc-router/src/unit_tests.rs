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
    assert!(schemas.get("zebra.BlockHash").is_some());
    assert!(schemas.get("zallet.WalletInfo").is_some());
    assert!(schemas.get("BlockHash").is_none());
}

#[test]
fn test_merge_openrpc_schemas_keeps_both_definitions_of_a_shared_name() {
    let zebra = json!({
        "openrpc": "1.2.6",
        "methods": [{
            "name": "getblocksubsidy",
            "params": [],
            "result": { "name": "subsidy", "schema": { "$ref": "#/components/schemas/Amount" } }
        }],
        "components": { "schemas": { "Amount": { "type": "integer" } } }
    });
    let zallet = json!({
        "openrpc": "1.3.2",
        "methods": [{
            "name": "z_getbalance",
            "params": [],
            "result": { "name": "balance", "schema": { "$ref": "#/components/schemas/Amount" } }
        }],
        "components": { "schemas": { "Amount": { "type": "number" } } }
    });

    let z3 = merge_openrpc_schemas(zebra, zallet).unwrap();
    let schemas = &z3.merged["components"]["schemas"];
    assert_eq!(schemas["zebra.Amount"]["type"], "integer");
    assert_eq!(schemas["zallet.Amount"]["type"], "number");

    let methods = z3.merged["methods"].as_array().unwrap();
    assert_eq!(
        methods[0]["result"]["schema"]["$ref"],
        "#/components/schemas/zebra.Amount"
    );
    assert_eq!(
        methods[1]["result"]["schema"]["$ref"],
        "#/components/schemas/zallet.Amount"
    );
}

#[test]
fn test_merge_openrpc_schemas_routing_uses_unprefixed_method_names() {
    let z3 = merge_openrpc_schemas(zebra_schema(), zallet_schema()).unwrap();
    assert!(z3.zebra_methods.iter().any(|m| m["name"] == "getblock"));
    assert!(z3.zallet_methods.iter().any(|m| m["name"] == "z_sendmany"));
}

// --- namespace_component_schemas ---

#[test]
fn test_namespace_rewrites_refs_nested_in_component_schemas() {
    let mut schema = json!({
        "methods": [{
            "name": "getblock",
            "params": [{ "name": "verbosity", "schema": { "$ref": "#/components/schemas/Verbosity" } }],
            "result": { "name": "block", "schema": {
                "oneOf": [
                    { "$ref": "#/components/schemas/BlockObject" },
                    { "type": "string" }
                ]
            } }
        }],
        "components": { "schemas": {
            "Verbosity": { "type": "integer" },
            "BlockObject": {
                "type": "object",
                "properties": {
                    "hash": { "$ref": "#/components/schemas/Hash" },
                    "tx": { "type": "array", "items": { "$ref": "#/components/schemas/Hash" } }
                }
            },
            "Hash": { "type": "string" }
        } }
    });

    namespace_component_schemas(&mut schema, "zebra");

    let schemas = schema["components"]["schemas"].as_object().unwrap();
    let mut names: Vec<_> = schemas.keys().cloned().collect();
    names.sort();
    assert_eq!(
        names,
        ["zebra.BlockObject", "zebra.Hash", "zebra.Verbosity"]
    );

    let method = &schema["methods"][0];
    assert_eq!(
        method["params"][0]["schema"]["$ref"],
        "#/components/schemas/zebra.Verbosity"
    );
    assert_eq!(
        method["result"]["schema"]["oneOf"][0]["$ref"],
        "#/components/schemas/zebra.BlockObject"
    );
    let block = &schemas["zebra.BlockObject"]["properties"];
    assert_eq!(block["hash"]["$ref"], "#/components/schemas/zebra.Hash");
    assert_eq!(
        block["tx"]["items"]["$ref"],
        "#/components/schemas/zebra.Hash"
    );
}

#[test]
fn test_namespace_leaves_other_refs_alone() {
    let mut schema = json!({
        "methods": [{
            "name": "m",
            "result": { "name": "r", "schema": { "$ref": "https://example.com/schema.json" } }
        }]
    });
    namespace_component_schemas(&mut schema, "zebra");
    assert_eq!(
        schema["methods"][0]["result"]["schema"]["$ref"],
        "https://example.com/schema.json"
    );
}

#[test]
fn test_namespace_without_components_does_not_panic() {
    let mut schema = json!({ "methods": [] });
    namespace_component_schemas(&mut schema, "zallet");
    assert!(schema.get("components").is_none());
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

#[test]
fn test_namespace_sanitizes_names_and_decodes_percent_encoded_refs() {
    let mut schema = json!({
        "methods": [{
            "name": "m",
            "result": { "name": "r", "schema": { "$ref": "#/components/schemas/Block%20Info" } }
        }],
        "components": { "schemas": { "Block Info": { "type": "object" } } }
    });
    namespace_component_schemas(&mut schema, "zallet");

    assert!(schema["components"]["schemas"]["zallet.Block_Info"].is_object());
    assert_eq!(
        schema["methods"][0]["result"]["schema"]["$ref"],
        "#/components/schemas/zallet.Block_Info"
    );
}

#[test]
fn test_namespace_replaces_remote_openrpc_meta_schema() {
    // The `rpc.discover` result schema Zallet 0.1.0-beta.1 publishes.
    let mut schema = json!({
        "methods": [{
            "name": "rpc.discover",
            "result": { "name": "OpenRPC Schema", "schema": { "$ref": "#/components/schemas/OpenRPC%20Schema" } }
        }],
        "components": { "schemas": {
            "OpenRPC Schema": {
                "$ref": "https://raw.githubusercontent.com/open-rpc/meta-schema/master/schema.json"
            }
        } }
    });
    namespace_component_schemas(&mut schema, "zallet");

    let schemas = schema["components"]["schemas"].as_object().unwrap();
    assert_eq!(schemas.len(), 1);
    assert_eq!(schemas["zallet.OpenRpcDocument"]["type"], "object");
    assert!(!schema.to_string().contains("raw.githubusercontent.com"));
    assert_eq!(
        schema["methods"][0]["result"]["schema"]["$ref"],
        "#/components/schemas/zallet.OpenRpcDocument"
    );
}

#[test]
fn test_namespace_keeps_names_apart_when_sanitizing_collides() {
    let mut schema = json!({
        "components": { "schemas": {
            "A B": { "type": "string" },
            "A_B": { "type": "integer" }
        } }
    });
    namespace_component_schemas(&mut schema, "zebra");
    assert_eq!(
        schema["components"]["schemas"].as_object().unwrap().len(),
        2
    );
}

#[test]
fn test_decode_ref_component_name() {
    assert_eq!(
        decode_ref_component_name("OpenRPC%20Schema"),
        "OpenRPC Schema"
    );
    assert_eq!(decode_ref_component_name("a~1b~0c"), "a/b~c");
    assert_eq!(decode_ref_component_name("bad%zz"), "bad%zz");
    assert_eq!(decode_ref_component_name("Plain"), "Plain");
}
