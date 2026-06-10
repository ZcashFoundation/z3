# Host-side pointer integration

Your service runs outside Docker: a host process, a CLI tool, a developer-laptop dev server. On mainnet and testnet, you connect to Z3 via the published host ports and inject the cookie text because you can't mount a Docker volume into a non-container process.

This integration type is less efficient than Compose-peer because every connection goes through the host network stack, but it fits development, scripting, and any service that lives outside Docker's lifecycle.

## Prerequisites

- A running Z3 stack: `docker compose --env-file .env.<network> up -d` in the Z3 repo.

## Connect via host ports

Host ports per network (full matrix in [`z3-contract.yaml`](../../z3-contract.yaml) under `networks.<name>.ports`):

| Service | Mainnet | Testnet | Regtest |
|---------|---------|---------|---------|
| Zebra RPC | `http://127.0.0.1:8232` | `http://127.0.0.1:18232` | `http://127.0.0.1:29232` |
| Zebra `/ready` | `http://127.0.0.1:8080/ready` | `http://127.0.0.1:18080/ready` | `http://127.0.0.1:28080/ready` |
| Zaino gRPC (plaintext h2c) | `127.0.0.1:8137` | `127.0.0.1:18137` | `127.0.0.1:28137` |
| Zaino JSON-RPC | `http://127.0.0.1:8237` | `http://127.0.0.1:18237` | `http://127.0.0.1:28237` |
| Zallet RPC | `http://127.0.0.1:28232` | `http://127.0.0.1:40232` | `http://127.0.0.1:50232` |
| rpc-router (regtest only) | n/a | n/a | `http://127.0.0.1:8181` |

Testnet uses a `+10000` host-port offset from mainnet for services without an upstream per-network convention; regtest uses explicit host ports to avoid collisions with mainnet/testnet.

## Read the RPC cookie

A host process cannot mount a Docker volume. On mainnet and testnet, copy the cookie text out:

```bash
# One-liner cookie reader
docker run --rm -v z3-mainnet-cookie:/auth:ro alpine \
  cat /auth/.cookie
```

Wrap it in a small helper your service runs at startup:

```bash
#!/usr/bin/env bash
# get-z3-cookie.sh: print the Z3 cookie text for a given network.
# Usage: ./get-z3-cookie.sh mainnet
set -euo pipefail
NETWORK="${1:-mainnet}"
docker run --rm -v "z3-${NETWORK}-cookie:/auth:ro" alpine cat /auth/.cookie
```

Your service then reads it via env:

```bash
export ZEBRA_RPC_URL=http://127.0.0.1:8232
export ZEBRA_COOKIE=$(./get-z3-cookie.sh mainnet)
./my-service
```

## Use the cookie in an HTTP request

Zebra's RPC auth expects HTTP Basic with the cookie as the password (Bitcoin Core / Zcash convention):

```bash
COOKIE="$(./get-z3-cookie.sh mainnet)"
curl -sf -u "$COOKIE" -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
  http://127.0.0.1:8232 | jq .
```

The cookie is in the format `__cookie__:<token>`; the colon is the username/password separator that `curl -u` expects. Regtest disables cookie auth; see the next section.

## Regtest auth

Regtest's contract declares `rpc_auth.mode: username_password`. The cookie volume exists but holds no readable cookie. Authenticate with HTTP Basic using the rpc-router credentials (defaults: `zebra` / `zebra`, override via `Z3_REGTEST_RPC_ROUTER_USER` / `Z3_REGTEST_RPC_ROUTER_PASSWORD` on the Z3 side):

```bash
# Direct to Zebra
curl -sf -u zebra:zebra -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
  http://127.0.0.1:29232 | jq .

# Through rpc-router (unified Zebra + Zallet JSON-RPC endpoint)
curl -sf -u zebra:zebra -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
  http://127.0.0.1:8181 | jq .
```

## Health check before connecting

Wait for Zebra to report ready before your service tries to talk to it:

```bash
# Block until Zebra reports ready (or fail after 10 minutes)
for i in $(seq 1 200); do
  if curl -sf http://127.0.0.1:8080/ready > /dev/null 2>&1; then
    echo "Zebra ready"; break
  fi
  if [ "$i" -eq 200 ]; then echo "Zebra never became ready"; exit 1; fi
  sleep 3
done
```

## When to use this integration vs Compose-peer

| Choose host-side pointer when | Choose Compose-peer when |
|--------------------------------|---------------------------|
| Your service is a dev server, REPL, or one-off script | Your service is a long-running daemon you ship in production |
| Your service is in a language without easy Docker integration | Your service deploys via Compose |
| You want to debug with native tools (gdb, dlv, language debuggers) | You want startup ordering via `depends_on` |
| You're iterating fast on the service itself | You're testing the consumer/platform integration |

Both integration types can coexist for the same service. A common pattern: production uses Compose-peer; local development uses host-side pointer with `pnpm dev` / `cargo run` / etc.
