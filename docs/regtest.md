# Z3 Regtest Environment

Local end-to-end testing of the full Z3 stack (Zebra, Zaino, Zallet, and the rpc-router) in regtest mode.

Uses the base `docker-compose.yml` with `docker-compose.regtest.yml` overlay and `.env.regtest` for regtest-specific configuration. Volumes are isolated via `COMPOSE_PROJECT_NAME=z3-regtest`, so regtest data never conflicts with mainnet or testnet.

## Prerequisites

- Docker with [Docker Compose](https://docs.docker.com/compose/install/) (v2.24.4+)
- For gRPC testing: [grpcurl](https://github.com/fullstorydev/grpcurl) and the Zaino proto files (`scripts/vendor.sh zaino`)

## First-time setup

From the repo root:

```bash
./scripts/regtest-init.sh
```

This will:

1. Copy the per-network config templates (`zebra.toml`, `zaino.toml`, `zallet.toml`) into live gitignored files
2. Generate the Zallet encryption identity in-container into the data volume (if not already present)
3. Generate and inject the Zallet RPC password hash in `config/regtest/zallet.toml`
4. Start Zebra in regtest mode with the activation heights Zaino expects (Canopy at 1, NU5/Orchard at 2)
5. Mine 2 blocks to activate Orchard
6. Initialize the Zallet wallet (`init-wallet-encryption` + `generate-mnemonic`)

Optionally override the rpc-router password (default is `zebra`). The `REGTEST_` infix marks the var as regtest-scoped:

```bash
Z3_REGTEST_RPC_ROUTER_PASSWORD='your-password' ./scripts/regtest-init.sh
```

## Start the stack

From the repo root:

```bash
docker compose --env-file .env.regtest up -d
```

Zebra, Zaino, and Zallet use pre-built images. The rpc-router builds from source on first run (takes a few minutes; subsequent runs use the Docker layer cache).

> [!NOTE]
> Regtest host ports are explicit and globally unique so all three networks (mainnet, testnet, regtest) can run concurrently on one host without binding collisions.

| Service | Endpoint | Description |
|---------|----------|-------------|
| rpc-router | http://localhost:8181 | JSON-RPC router (Zebra + Zallet) |
| Zaino gRPC | localhost:28137 | lightwalletd-compatible gRPC (plaintext h2c) |
| Zebra RPC | http://localhost:29232 | Direct Zebra JSON-RPC |
| Zallet RPC | http://localhost:50232 | Direct Zallet JSON-RPC |

## Test routing

These commands go through the rpc-router, which forwards to Zebra or Zallet based on the method:

```bash
# Route to Zebra (full node)
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
  http://127.0.0.1:8181

# Route to Zallet (wallet)
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getwalletinfo","params":[],"id":2}' \
  http://127.0.0.1:8181

# Merged OpenRPC schema
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"rpc.discover","params":[],"id":3}' \
  http://127.0.0.1:8181 | grep -o '"title":"[^"]*"'
```

## Test Zaino gRPC

Zaino exposes the [lightwalletd-compatible gRPC protocol](https://github.com/zcash/lightwalletd/blob/master/walletrpc/service.proto) as plaintext h2c (no TLS). In regtest the host port is `28137` (`Z3_ZAINO_HOST_GRPC_PORT`); the `-plaintext` flag tells grpcurl to skip TLS.

Fetch the Zaino proto files if you haven't already:

```bash
scripts/vendor.sh zaino
```

Test with `GetLightdInfo` (from the repo root):

```bash
grpcurl -plaintext \
  -import-path vendor/zaino/zaino-proto/proto \
  -proto service.proto \
  127.0.0.1:28137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLightdInfo
```

Get the latest block height:

```bash
grpcurl -plaintext \
  -import-path vendor/zaino/zaino-proto/proto \
  -proto service.proto \
  -d '{}' \
  127.0.0.1:28137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLatestBlock
```

## OpenRPC Playground

Open the playground pointed at your locally running router:

<https://playground.open-rpc.org/?uiSchema[appBar][ui:title]=Zcash&uiSchema[appBar][ui:logoUrl]=https://z.cash/wp-content/uploads/2023/03/zcash-logo.gif&schemaUrl=http://127.0.0.1:8181&uiSchema[appBar][ui:splitView]=false&uiSchema[appBar][ui:edit]=false&uiSchema[appBar][ui:input]=false&uiSchema[appBar][ui:examplesDropdown]=false&uiSchema[appBar][ui:transports]=false>

The playground calls `rpc.discover` on `http://127.0.0.1:8181` to load the live merged schema.

## Stop and clean up

```bash
# Stop containers (keeps volumes/wallet data)
docker compose --env-file .env.regtest down

# Full reset (deletes all regtest data; re-run scripts/regtest-init.sh afterwards)
docker compose --env-file .env.regtest down -v
```

## Expected output

**`getblockchaininfo`** (routed to Zebra, truncated):

```json
{"jsonrpc":"2.0","id":1,"result":{"chain":"test","blocks":1,"headers":1,...,"upgrades":{"5ba81b19":{"name":"Overwinter","activationheight":1,"status":"active"},...}}}
```

**`getwalletinfo`** (routed to Zallet):

```json
{"jsonrpc":"2.0","result":{"walletversion":0,"balance":0.00000000,"unconfirmed_balance":0.00000000,"immature_balance":0.00000000,"shielded_balance":"0.00","shielded_unconfirmed_balance":"0.00","txcount":0,"keypoololdest":0,"keypoolsize":0,"mnemonic_seedfp":"TODO"},"id":1}
```

## Monitoring in regtest

Zebra's Prometheus endpoint is enabled by default on the internal `zebra:9999` scrape target. Start the monitoring profile:

```bash
docker compose --env-file .env.regtest --profile monitoring up -d
```

Regtest monitoring UI ports are Grafana `23000`, Prometheus `29094`, Jaeger UI `36686`, and AlertManager `29093`. Jaeger also publishes OTLP gRPC `25317`, OTLP HTTP `25318`, and spanmetrics `28889`.

## Notes

- Credentials: `zebra` / `zebra` (hardcoded for regtest only)
- Regtest activates upgrades through Canopy at block 1 and NU5/Orchard at block 2 (Zebra, Zaino, and Zallet all agree)
- Zaino uses username/password auth in regtest (not cookie auth)
- Zaino gRPC is plaintext h2c on all networks; terminate edge TLS at a reverse proxy if exposed beyond the host
- The rpc-router source is in `rpc-router/`; it is built automatically on first `docker compose up`
