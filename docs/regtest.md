# Z3 Regtest Environment

Local end-to-end testing of the full Z3 stack (Zebra, Zaino, Zallet, and the rpc-router) in regtest mode.

Uses the base `docker-compose.yml` with `docker-compose.regtest.yml` overlay and `.env.regtest` for regtest-specific configuration. Volumes are isolated via `COMPOSE_PROJECT_NAME=z3-regtest`, so regtest data never conflicts with mainnet or testnet.

## Prerequisites

- Docker with [Docker Compose](https://docs.docker.com/compose/install/) (v2.24.0+)
- [rage](https://github.com/str4d/rage/releases) for generating Zallet encryption keys
- TLS certificates generated (see Quick Start in the main [README](../README.md))
- For gRPC testing: [grpcurl](https://github.com/fullstorydev/grpcurl) and the zaino submodule initialized (`git submodule update --init zaino`)

## First-time setup

From the repo root:

```bash
./scripts/regtest-init.sh
```

This will:

1. Generate a Zallet encryption identity (if not already present)
2. Generate and inject the Zallet RPC password hash in `config/regtest/zallet.toml`
3. Start Zebra in regtest mode
4. Mine 1 block (activates Orchard at height 1)
5. Initialize the Zallet wallet (`init-wallet-encryption` + `generate-mnemonic`)

Optionally override the RPC password (default is `zebra`):

```bash
RPC_PASSWORD='your-password' ./scripts/regtest-init.sh
```

## Start the stack

From the repo root:

```bash
docker compose --env-file .env.regtest up -d
```

Zebra, Zaino, and Zallet use pre-built images. The rpc-router builds from source on first run (takes a few minutes; subsequent runs use the Docker layer cache).

> [!NOTE]
> Regtest uses the same host ports as mainnet/testnet. If other Z3 services are running, stop them first (`docker compose down`) or override port variables in `.env.regtest`.

| Service | Endpoint | Description |
|---------|----------|-------------|
| rpc-router | http://localhost:8181 | JSON-RPC router (Zebra + Zallet) |
| Zaino gRPC | https://localhost:8137 | lightwalletd-compatible gRPC (TLS) |
| Zebra RPC | http://localhost:18232 | Direct Zebra JSON-RPC |
| Zallet RPC | http://localhost:28232 | Direct Zallet JSON-RPC |

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

Zaino exposes the [lightwalletd-compatible gRPC protocol](https://github.com/zcash/lightwalletd/blob/master/walletrpc/service.proto) on port 8137 with TLS. The `--insecure` flag tells grpcurl to accept the self-signed certificate.

Initialize the zaino submodule if you haven't already (needed for the proto files):

```bash
git submodule update --init zaino
```

Test with `GetLightdInfo` (from the repo root):

```bash
grpcurl -insecure \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLightdInfo
```

Get the latest block height:

```bash
grpcurl -insecure \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  -d '{}' \
  127.0.0.1:8137 \
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

To enable monitoring, add the metrics endpoint to `.env.regtest`:

```bash
ZEBRA_METRICS__ENDPOINT_ADDR=0.0.0.0:9999
```

Then start with both flags:

```bash
docker compose --env-file .env.regtest --profile monitoring up -d
```

The port (9999) must match the Prometheus scrape target configured in `observability/prometheus/prometheus.yaml`.

## Notes

- Credentials: `zebra` / `zebra` (hardcoded for regtest only)
- Zallet uses regtest nuparams activating all upgrades at block 1
- Zaino uses username/password auth in regtest (not cookie auth)
- Zaino gRPC uses TLS with the same self-signed certificate as mainnet/testnet
- The rpc-router source is in `rpc-router/`; it is built automatically on first `docker compose up`
