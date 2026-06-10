# Z3 integration examples

How downstream services attach to a running Z3 stack. Pick the example that matches how your service deploys.

| Integration type | When to use it | Example |
|-----------|----------------|---------|
| Compose-peer | Your service runs as a Docker container in the same logical stack as Z3 | [compose-peer.md](compose-peer.md) |
| Host-side pointer | Your service runs outside Docker (a host process, a CLI tool, a developer-laptop dev server) | [host-side-pointer.md](host-side-pointer.md) |
| Lightwalletd-compatible client | Your service is a wallet or block explorer that speaks the `CompactTxStreamer` gRPC protocol | [lightwalletd-client.md](lightwalletd-client.md) |
| Ephemeral test fixture | Your test suite needs a controlled, deterministic chain | NOT a Z3 attachment; see [the ephemeral-fixture note](#ephemeral-test-fixtures) below |

All examples assume a running Z3 stack on the relevant network. Bring one up first:

```bash
cd <z3-repo>
docker compose --env-file .env.mainnet up -d    # or testnet/regtest
```

See [`contract.md`](../contract.md) for the public identifiers each example references.

## Conventions

Examples use `<network>` as a placeholder for the network you're targeting. Cookie-auth examples apply to mainnet and testnet; regtest disables cookie auth and uses username/password through its regtest configs and rpc-router.

Volume and network names follow the contract pattern `z3-<network>-<resource>` (and `z3-<network>` for the external network). Verify the exact names with:

```bash
./scripts/validate-contract.py
```

## Ephemeral test fixtures

If your test suite needs a fresh chain on every run, a fixed tip, or full control over consensus parameters, **don't** attach to a shared Z3 stack. Spin up an ephemeral Zebra (the existing `zebra-test` harness or a per-test `zebrad` binary) and tear it down with the test.

If your tests need an indexer or wallet behind that ephemeral Zebra, run them per-test too. Sharing chain state across parallel tests is what makes them flaky.
