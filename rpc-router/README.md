# Z3 RPC Router

The **Z3 RPC Router** (`rpc-router` crate) provides a single JSON-RPC endpoint on top of the Zebra and Zallet RPC servers.

It exposes a new port where incoming RPC requests are transparently routed to the appropriate backend:

- RPC methods belonging to Zebra are forwarded to the Zebra RPC endpoint.
- RPC methods belonging to Zallet are forwarded to the Zallet RPC endpoint.

From the point of view of a dApp built on top of the Zcash Z3 stack, this means there is a single RPC endpoint to interact with, while all routing happens in the background.

In addition to request routing, the router also:

- Calls `rpc.discover` on both Zebra and Zallet at startup
- Builds a merged OpenRPC schema for the Z3 stack
- Exposes the merged schema via its own `rpc.discover` method

## Developer Usage

To run the router, Zebra and Zallet must already be running, fully synced, and responsive on known ports **before** starting the router. At startup the router calls `rpc.discover` on both backends to build the merged schema — if either is unreachable the router exits immediately with an error.

The router accepts this configuration via environment variables, or alternatively you can modify the values directly in main.rs.

### Running Zebra and Zallet for Development

The easiest way to get Zebra and Zallet running locally is via the Docker Compose stack at the root of this repository:

```bash
docker compose up -d zebra zallet
```

Wait until both services are healthy, then note the RPC ports from your `.env` file (or the defaults in `docker-compose.yml`) and pass them to the router.

> **Note:** A `openrpc.py` QA helper that spawned Zebra and Zallet in regtest mode previously existed in the Zebra repository but was removed. It has not been ported to the [zcash/integration-tests](https://github.com/zcash/integration-tests) repository.

> **Note:** For experimental Z3 regtest mode of the router see [Regtest Environment](regtest/README.md).

### Running the RPC Router

```bash
RUST_LOG=info \
ZEBRA_URL=http://localhost:<zebra-rpc-port>/ \
ZALLET_URL=http://localhost:<zallet-rpc-port>/ \
cargo run
```

Example output:

```bash
INFO rpc_router: RPC Router listening on 0.0.0.0:8080
INFO rpc_router: You can use the following playground URL:
INFO rpc_router: https://playground.open-rpc.org/?...
```

At this point, the router is listening on `http://localhost:8080`.

### Querying the Router

You can use standard JSON-RPC clients (such as `curl`) to call methods exposed by either Zebra or Zallet through the router.

#### Example: Zebra RPC Call

```bash
curl --silent -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getinfo","params":[],"id":123}' \
  http://127.0.0.1:8080 | jq
```

On the router side, you should see:

```bash
INFO rpc_router: Routing getinfo to Zebra
```

#### Example: Zallet RPC Call

```bash
curl --silent -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getwalletinfo","params":[],"id":123}' \
  http://127.0.0.1:8080 | jq
```

And on the router logs:

```bash
INFO rpc_router: Routing getwalletinfo to Zallet
```

### OpenRPC Playground

You can interact with the merged OpenRPC schema using the OpenRPC Playground, pointed at your running router:

[Playground](https://playground.open-rpc.org/?uiSchema[appBar][ui:title]=Zcash&uiSchema[appBar][ui:logoUrl]=https://z.cash/wp-content/uploads/2023/03/zcash-logo.gif&schemaUrl=http://127.0.0.1:8080&uiSchema[appBar][ui:splitView]=false&uiSchema[appBar][ui:edit]=false&uiSchema[appBar][ui:input]=false&uiSchema[appBar][ui:examplesDropdown]=false&uiSchema[appBar][ui:transports]=false)

When using the inspector, make sure the target server URL is set to:

```
http://localhost:8080/
```

The RPC router automatically sets the required CORS headers, allowing the playground (or other browser-based tools) to call the local endpoint directly.

By default the `Access-Control-Allow-Origin` header is set to `https://playground.open-rpc.org`. To allow a different origin (e.g. a dApp frontend or any browser client), set the `CORS_ORIGIN` environment variable:

```bash
CORS_ORIGIN=https://myapp.example.com cargo run
```

For local development you can use `CORS_ORIGIN=*` to allow all origins. Avoid using `*` in production as it allows any website to call your local node.
