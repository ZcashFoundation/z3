# RPC Router — Regtest Environment

Self-contained Docker Compose setup for local end-to-end testing of the rpc-router against real Zebra and Zallet backends in regtest mode.

**Does not touch the production stack** in the repo root.

## Prerequisites

- Docker with the `z3-zallet:local` image built:
  ```bash
  cd ../../   # repo root
  docker compose build zallet
  ```

## First-time setup

```bash
cd rpc-router/regtest
./init.sh
```

This will:
1. Start Zebra in regtest mode
2. Mine 1 block (activates Orchard at height 1)
3. Generate and inject the Zallet `rpc.auth.pwhash` in `config/zallet.toml`
4. Initialize the Zallet wallet (`init-wallet-encryption` + `generate-mnemonic`)

Optional: override the RPC password used for the hash generation:

This (default) password which is included in zcash/integration-tests is not checked into the repo to avoid offending the kingphisher and other code scanning gods.

```bash
RPC_PASSWORD='your-password' ./init.sh
```

## Start the stack

```bash
sudo -E docker compose up -d
```

Router is available at **http://localhost:8181**.

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
- The rpc-router Dockerfile is in `rpc-router/` (one level up)

## Tested environment

Successfully tested on:

- **OS**: Linux Mint 21.2 (kernel 5.15.0-171-generic).  also Debian GNU/Linux 13 (trixie) (kernel 6.12.69+deb13-cloud-amd64)
- **Rust**: 1.90.0 (rpc-router built locally; Docker image uses `rust-1.85`), also 1.94.0
- **Docker Compose**: v5.1.0 (plugin, not standalone `docker-compose`)
- **Zallet image**: `z3-zallet:local` built from submodule at `ae762c05` (Feb 2026), also built from submodule at `757876b` (March 2026)
- **Zebra image**: `zfnd/zebra:3.1.0` and `zfnd/zebra:4.1.0`

Expected output for the test commands above:

**`getwalletinfo`** → routed to Zallet:
```json
{"jsonrpc":"2.0","result":{"walletversion":0,"balance":0.00000000,"unconfirmed_balance":0.00000000,"immature_balance":0.00000000,"shielded_balance":"0.00","shielded_unconfirmed_balance":"0.00","txcount":0,"keypoololdest":0,"keypoolsize":0,"mnemonic_seedfp":"TODO"},"id":1}
```

**`getblockchaininfo`** → routed to Zebra (truncated):
```json
{"jsonrpc":"2.0","id":1,"result":{"chain":"test","blocks":1,"headers":1,...,"upgrades":{"5ba81b19":{"name":"Overwinter","activationheight":1,"status":"active"},...}}}
```
