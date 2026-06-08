# Lightwalletd-compatible client integration

Your service is a wallet, block explorer, or scanner that speaks the lightwalletd `CompactTxStreamer` gRPC protocol. Z3's Zaino exposes that protocol with TLS on the documented port.

## Prerequisites

- A running Z3 stack: `docker compose --env-file .env.<network> up -d` in the Z3 repo.
- A gRPC client for your language (Tonic for Rust, grpcio for Python, grpc-java, etc.) or the `grpcurl` CLI for ad-hoc calls.
- The lightwalletd / Zaino `.proto` files. Either vendor them or pull from the Zaino submodule (`zaino/zaino-proto/proto/service.proto`).

## Endpoint per network

Zaino's gRPC port uses TLS and follows the contract's port matrix:

| Network | Host endpoint |
|---------|----------------|
| Mainnet | `https://127.0.0.1:8137` |
| Testnet | `https://127.0.0.1:18137` |
| Regtest | `https://127.0.0.1:28137` |

The certificate is self-signed (generated at first install). Production deployments should replace `config/tls/zaino.{crt,key}` with certificates from a trusted CA.

## Regtest auth

Regtest's contract declares `rpc_auth.mode: username_password` for Zebra and Zallet; Zaino authenticates internally to Zebra using the same username/password (from `config/regtest/zaino.toml`). The Zaino gRPC surface itself does not require client auth on any network. The cookie volume `z3-regtest-cookie` exists but holds no readable cookie. If your test setup needs to talk to Zebra directly (mine blocks, inspect state), use the rpc-router host endpoint at `http://127.0.0.1:8181` with HTTP Basic, defaults `zebra` / `zebra` (override on the Z3 side via `Z3_REGTEST_RPC_ROUTER_USER` / `Z3_REGTEST_RPC_ROUTER_PASSWORD`).

## Quick test with `grpcurl`

The .proto files are already vendored in this repo as a submodule under
`zaino/zaino-proto/proto/`. Initialize it once and point grpcurl at that path.

```bash
# One-time: fetch the vendored Zaino submodule
git submodule update --init zaino

# Probe the endpoint (mainnet example)
grpcurl -insecure \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLightdInfo

# Get the latest block
grpcurl -insecure \
  -import-path zaino/zaino-proto/proto \
  -proto service.proto \
  -d '{}' \
  127.0.0.1:8137 \
  cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLatestBlock
```

`--insecure` accepts the self-signed certificate. In production, configure your gRPC client to trust the actual CA your TLS cert was issued by.

## Rust (Tonic) example

```rust
use tonic::transport::{Channel, ClientTlsConfig, Endpoint};
use compact_tx_streamer_client::CompactTxStreamerClient;

let tls_config = ClientTlsConfig::new()
    .with_native_roots()       // or .ca_certificate(...) for a custom CA
    .domain_name("localhost");

let channel = Endpoint::from_static("https://127.0.0.1:8137")
    .tls_config(tls_config)?
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
    baseUrl: "https://127.0.0.1:8137",
    nodeOptions: { rejectUnauthorized: false },   // for self-signed certs only
});

const client = createClient(CompactTxStreamer, transport);
const info = await client.getLightdInfo({});
```

## What's the difference between Zaino and Zallet?

| Service | Audience | Protocol |
|---------|----------|----------|
| **Zaino** | External light-wallet clients (mobile wallets, scanners) | gRPC `CompactTxStreamer` over TLS |
| **Zallet** | Operator wallet (the operator's own keys, full RPC surface) | JSON-RPC over HTTP |

If you're writing a mobile wallet or a public-facing scanner, use Zaino. If you're administering the operator's wallet (creating addresses, sending transactions, importing keys), use Zallet.

## TLS in production

The default self-signed cert is fine for local development. For any deployment exposed beyond `127.0.0.1`:

1. Get a certificate from a trusted CA for the hostname clients will dial.
2. Replace `config/tls/zaino.{crt,key}` with the new files.
3. Restart Zaino: `docker compose --env-file .env.<network> restart zaino`.
4. Configure your client to validate the cert against the CA (drop the `--insecure` / `rejectUnauthorized: false`).

The TLS cert is the same across all networks (shared file); only the gRPC host port differs per network.
