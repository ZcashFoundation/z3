# Lightwalletd-compatible client integration

Your service is a wallet, block explorer, or scanner that speaks the lightwalletd `CompactTxStreamer` gRPC protocol. Z3's Zaino exposes that protocol as plaintext HTTP/2 (h2c) on the documented port. Terminate TLS at a reverse proxy if you expose Zaino beyond the host (see [Edge TLS in production](#edge-tls-in-production)).

## Prerequisites

- A running Z3 stack: `docker compose --env-file .env.<network> up -d` in the Z3 repo.
- A gRPC client for your language (Tonic for Rust, grpcio for Python, grpc-java, etc.) or the `grpcurl` CLI for ad-hoc calls.
- The lightwalletd / Zaino `.proto` files. Either vendor them or pull from the Zaino submodule (`zaino/zaino-proto/proto/service.proto`).

## Endpoint per network

Zaino's gRPC port is plaintext h2c and follows the contract's port matrix:

| Network | Host endpoint |
|---------|----------------|
| Mainnet | `127.0.0.1:8137` |
| Testnet | `127.0.0.1:18137` |
| Regtest | `127.0.0.1:28137` |

There is no TLS on this listener. The Z3 stack runs Zaino with its TLS guard compiled out (the `-no-tls` image), so intra-stack and host-side gRPC is unencrypted. Anything exposed to a network you do not control should sit behind a TLS-terminating reverse proxy.

## Regtest auth

Regtest's contract declares `rpc_auth.mode: username_password` for Zebra and Zallet; Zaino authenticates internally to Zebra using the same username/password (from `config/regtest/zaino.toml`). The Zaino gRPC surface itself does not require client auth on any network. The cookie volume `z3-regtest-cookie` exists but holds no readable cookie. If your test setup needs to talk to Zebra directly (mine blocks, inspect state), use the rpc-router host endpoint at `http://127.0.0.1:8181` with HTTP Basic, defaults `zebra` / `zebra` (override on the Z3 side via `Z3_REGTEST_RPC_ROUTER_USER` / `Z3_REGTEST_RPC_ROUTER_PASSWORD`).

## Quick test with `grpcurl`

The .proto files are already vendored in this repo as a submodule under
`zaino/zaino-proto/proto/`. Initialize it once and point grpcurl at that path.

```bash
# One-time: fetch the vendored Zaino submodule
git submodule update --init zaino

# Probe the endpoint (mainnet example). -plaintext skips TLS.
grpcurl -plaintext \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLightdInfo

# Get the latest block
grpcurl -plaintext \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  -d '{}' \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLatestBlock
```

## Rust (Tonic) example

```rust
use tonic::transport::{Channel, Endpoint};
use compact_tx_streamer_client::CompactTxStreamerClient;

// Plaintext h2c: use http:// and no TLS config.
let channel = Endpoint::from_static("http://127.0.0.1:8137")
    .connect()
    .await?;

let mut client = CompactTxStreamerClient::new(channel);
let info = client.get_lightd_info(()).await?.into_inner();
println!("Lightd info: {info:?}");
```

## TypeScript (Connect-ES) example

```typescript
import { createGrpcTransport } from "@connectrpc/connect-node";
import { createClient } from "@connectrpc/connect";
import { CompactTxStreamer } from "./gen/service_pb";

const transport = createGrpcTransport({
    httpVersion: "2",
    baseUrl: "http://127.0.0.1:8137",   // plaintext h2c; no TLS
});

const client = createClient(CompactTxStreamer, transport);
const info = await client.getLightdInfo({});
```

## What's the difference between Zaino and Zallet?

| Service | Audience | Protocol |
|---------|----------|----------|
| **Zaino** | External light-wallet clients (mobile wallets, scanners) | gRPC `CompactTxStreamer` over plaintext h2c |
| **Zallet** | Operator wallet (the operator's own keys, full RPC surface) | JSON-RPC over HTTP |

If you're writing a mobile wallet or a public-facing scanner, use Zaino. If you're administering the operator's wallet (creating addresses, sending transactions, importing keys), use Zallet.

## Edge TLS in production

The gRPC listener is plaintext, which is fine inside the Docker network and for local development. Wallet clients on the public internet expect TLS, so for any deployment exposed beyond `127.0.0.1`:

1. Put a reverse proxy (nginx, Caddy, Envoy, or your cloud load balancer) in front of Zaino and terminate TLS there with a certificate from a trusted CA.
2. Proxy decrypted h2c traffic to Zaino's gRPC port on the internal network.
3. Point clients at the proxy's `https://` endpoint; the proxy handles TLS and forwards plaintext gRPC to Zaino.

This keeps certificate management at the edge where it belongs, rather than baking a self-signed cert into the node stack.
