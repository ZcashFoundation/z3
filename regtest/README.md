# Z3 Regtest Environment

Self-contained Docker Compose setup for local end-to-end testing of the full Z3 stack (Zebra, Zaino, Zallet, and the rpc-router) in regtest mode.

**Does not touch the production stack** in the repo root.

## Prerequisites

- Docker with local images built (from the repo root):
  ```bash
  cd ..   # repo root
  docker compose build zallet
  docker compose -f regtest/docker-compose.yml build zaino
  ```

## First-time setup

```bash
cd regtest
./init.sh
```

This will:
1. Start Zebra in regtest mode
2. Mine 1 block (activates Orchard at height 1)
3. Generate and inject the Zallet `rpc.auth.pwhash` in `config/zallet.toml`
4. Initialize the Zallet wallet (`init-wallet-encryption` + `generate-mnemonic`)

Optionally override the RPC password (default is `zebra`):

```bash
RPC_PASSWORD='your-password' ./init.sh
```

## Start the stack

```bash
sudo -E docker compose up -d
```

Router is available at **http://localhost:8181**.
Zaino gRPC (lightwalletd-compatible) is available at **localhost:8137**.

## Test routing

```bash
# Route to Zebra (full node)
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
  http://127.0.0.1:8181

# Route to Zallet (wallet)
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"getwalletinfo","params":[],"id":2}' \
  http://127.0.0.1:8181

# Merged OpenRPC schema title
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"rpc.discover","params":[],"id":3}' \
  http://127.0.0.1:8181 | grep -o '"title":"[^"]*"'
```

## Test Zaino gRPC

Zaino exposes the [lightwalletd-compatible gRPC protocol](https://github.com/zcash/lightwalletd/blob/master/walletrpc/service.proto) (`cash.z.wallet.sdk.rpc.CompactTxStreamer`) directly on port `8137`.

Install [grpcurl](https://github.com/fullstorydev/grpcurl):
```bash
# macOS
brew install grpcurl

# Linux (download binary from https://github.com/fullstorydev/grpcurl/releases)
```

Test with `GetLightdInfo` (no request body needed — equivalent of `getinfo`). Run from the **repo root**:
```bash
grpcurl -plaintext \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLightdInfo
```

Get the latest block height (run from **repo root**):
```bash
grpcurl -plaintext \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  -d '{}' \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLatestBlock
```

## OpenRPC Playground

Open the playground pointed at your locally running router:

https://playground.open-rpc.org/?uiSchema[appBar][ui:title]=Zcash&uiSchema[appBar][ui:logoUrl]=https://z.cash/wp-content/uploads/2023/03/zcash-logo.gif&schemaUrl=http://127.0.0.1:8181&uiSchema[appBar][ui:splitView]=false&uiSchema[appBar][ui:edit]=false&uiSchema[appBar][ui:input]=false&uiSchema[appBar][ui:examplesDropdown]=false&uiSchema[appBar][ui:transports]=false

The playground will call `rpc.discover` on `http://127.0.0.1:8181` to load the live merged schema.

## Stop and clean up

```bash
# Stop all containers (keeps volumes/wallet data)
sudo -E docker compose down

# Stop and delete all volumes (full reset — re-run init.sh afterwards)
sudo -E docker compose down -v
```

## Notes

- Credentials: `zebra` / `zebra` (hardcoded for regtest only)
- Zallet uses regtest nuparams activating all upgrades at block 1
- The rpc-router Dockerfile is in `rpc-router/`
- Zaino gRPC (port 8137) is the lightwalletd-compatible interface for light wallet clients; it is exposed directly and not routed through the rpc-router

## Tested environment

Successfully tested on:

- **OS**: Linux Mint 21.2 (kernel 5.15.0-171-generic). Also Debian GNU/Linux 13 (trixie) (kernel 6.12.69+deb13-cloud-amd64)
- **Rust**: 1.85.0–1.94.0
- **Docker Compose**: v5.1.0 (plugin, not standalone `docker-compose`)
- **Zebra image**: `zfnd/zebra:4.2.0`
- **Zaino**: built from submodule at `aaaaa71c` (rc/0.2.0, March 2026)
- **Zallet image**: `z3_zallet:local` built from submodule at `757876b` (March 2026)

Expected output for the test commands above:

**`getwalletinfo`** → routed to Zallet:
```json
{"jsonrpc":"2.0","result":{"walletversion":0,"balance":0.00000000,"unconfirmed_balance":0.00000000,"immature_balance":0.00000000,"shielded_balance":"0.00","shielded_unconfirmed_balance":"0.00","txcount":0,"keypoololdest":0,"keypoolsize":0,"mnemonic_seedfp":"TODO"},"id":1}
```

**`getblockchaininfo`** → routed to Zebra (truncated):
```json
{"jsonrpc":"2.0","id":1,"result":{"chain":"test","blocks":1,"headers":1,...,"upgrades":{"5ba81b19":{"name":"Overwinter","activationheight":1,"status":"active"},...}}}
```
