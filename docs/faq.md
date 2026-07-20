# Z3 FAQ

Answers to behaviors that look like bugs but are working as designed, plus a few real footguns. This FAQ answers "why is the thing I'm running behaving this way?". For how the stack is built internally, see [docker-architecture.md](docker-architecture.md).

Questions are grouped by what you are doing:

- **[For operators](#for-operators)**: running the stack as infrastructure.
- **[For developers and testers](#for-developers-and-testers)**: building or testing against Z3, often across several networks at once.

When an entry says "see README", the fix lives there; this FAQ only adds the diagnostic context.

---

## For operators

### Q: Why is my Zebra container marked `unhealthy` right after start?

That's the `/ready` probe doing its job, not a fault. `/ready` requires the node to have at least `ZEBRA_HEALTH__MIN_CONNECTED_PEERS` (default `1`) and to be within `ZEBRA_HEALTH__READY_MAX_BLOCKS_BEHIND` (default `2`) of the network tip. A fresh start from a cold chain, or a restart on a cache that's a few minutes behind, will report `unhealthy` until both thresholds are met.

For development, `/healthy` is a looser signal that only checks peer connectivity. The tracked `docker-compose.override.yml.example` flips the healthcheck to `/healthy` so Zallet (and Zaino under the indexer profile) can start without waiting for full sync. Use it for dev, never for production where you want consumers to wait for a synced node.

Don't run `docker compose up -d` (it starts Zallet) until Zebra reports `/ready`. The poller `scripts/check-zebra-readiness.sh` waits for exactly that. README Quick start step 3 explains the two-phase boot.

---

### Q: Where does z3 store chain state, and what do I actually back up?

Chain state for each network is a Docker named volume, `z3-<network>-chain`, under Docker's data root (`/var/lib/docker/volumes/` on Linux). Mainnet is roughly 300 GB. Find the exact path with:

```bash
docker volume inspect z3-mainnet-chain -f '{{.Mountpoint}}'
```

To keep it off the OS disk, set `Z3_CHAIN_DATA_PATH=/mnt/ssd/zebra-state` and run `./scripts/fix-permissions.sh zebra /mnt/ssd/zebra-state` before the first start.

For backups, the only thing worth keeping is the `z3-<network>-zallet` volume. It holds the age-encrypted wallet database **and** the identity that decrypts it, so the volume is self-contained: restore it and the wallet opens. Chain state is re-syncable and the RPC cookie is regenerated on boot, so neither belongs in a backup.

`docker compose --env-file .env.<network> --profile "*" down` keeps all volumes; `down -v` deletes them and forces a full re-sync. Include `--profile "*"` so profile-gated services (indexer, monitoring) are stopped too.

---

### Q: How do I set up the Zallet wallet on mainnet or testnet?

`scripts/regtest-init.sh` initializes the regtest wallet automatically. On mainnet and testnet, the node runs fine without an initialized wallet; set up Zallet's wallet encryption yourself, once per network, when you are ready to manage keys. Zallet runs as uid 1000 but the distroless image ships no data directory, so a freshly created volume is root-owned: make it writable once, then generate the identity and initialize encryption:

```bash
# One-time: make the data volume writable by Zallet's uid (1000).
docker run --rm -v z3-<network>-zallet:/data busybox chown 1000:1000 /data

docker compose --env-file .env.<network> run --rm --no-deps zallet \
  --datadir /var/lib/zallet --config /etc/zallet/zallet.toml generate-encryption-identity

docker compose --env-file .env.<network> run --rm --no-deps zallet \
  --datadir /var/lib/zallet --config /etc/zallet/zallet.toml init-wallet-encryption
```

`--no-deps` skips starting Zebra (encryption setup does not need it). `generate-encryption-identity` writes the age key into the `z3-<network>-zallet` volume and refuses to overwrite an existing identity, so re-running it is safe. Each network keeps its Zallet data in a separate volume, so run this once per network you use. Back up the volume (see the data question above): it holds both the wallet and the identity that decrypts it. Afterwards, use the Zallet RPC or `generate-mnemonic` to create or import keys.

---

### Q: Why doesn't z3 set a logging driver, and how do I cap log size?

By design. Pinning `logging.driver` in the compose file would override whatever logging driver you set on the Docker daemon (journald, local, awslogs, a remote collector). z3 leaves logging unset so your daemon default wins.

To bound disk growth on a 24/7 node, set a rotating default once in `/etc/docker/daemon.json` and restart the daemon:

```json
{
  "log-driver": "local",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
```

The `local` driver rotates by default and is more efficient than `json-file`. This applies to every container on the host, not just z3. If you want per-service control, add a `logging:` block in your operator-local override file.

---

### Q: Why is my container free to use all of my host's CPU and RAM?

Because `docker-compose.yml` doesn't set `deploy.resources.limits` on any service. The choice is deliberate for a node platform: a constrained limit that makes sense on a 4-core laptop will silently throttle a 32-core production host, and the bound that's right for one operator is wrong for the next.

If you want to bound a single noisy service (a bulk indexer, a one-off backfill) without hand-tuning everything else, add the limit in your operator-local override file rather than the tracked compose:

```yaml
# docker-compose.override.yml (mainnet) or docker-compose.testnet.override.yml (testnet)
services:
  zebra:
    deploy:
      resources:
        limits:
          cpus: "8"
          memory: 8g
```

Keep the limit generous on the service you want to win contention (Zebra), tight on the service you want to lose it (the noisy consumer). Don't add limits to services you haven't actually seen misbehave, since under-sized limits cause more outages than they prevent.

---

### Q: How do I track Zebra's latest image without updating Z3?

Z3's checked-in defaults stay pinned so a `docker compose pull` cannot silently change the node version for every operator. If you prefer fewer Z3 stack updates and accept a moving Zebra image, set the image override in your operator-local `.env`:

```bash
Z3_ZEBRA_IMAGE=zfnd/zebra:latest
```

Then pull before recreating Zebra. Docker does not fetch a newer image just because the tag is named `latest`; run `pull` first or use `up --pull always`. When you use the documented `--env-file .env.<network>` commands, pass `.env` after the network file so the override is loaded:

```bash
docker compose --env-file .env.mainnet --env-file .env pull zebra
docker compose --env-file .env.mainnet --env-file .env up -d zebra

# Equivalent one-command form:
docker compose --env-file .env.mainnet --env-file .env up -d --pull always zebra
```

For testnet or regtest, replace `.env.mainnet` with `.env.testnet` or `.env.regtest`. If you run mainnet without `--env-file`, Compose auto-loads `.env`, so `docker compose up -d --pull always zebra` is enough.

The same override pattern works for other services through `Z3_ZAINO_IMAGE` and `Z3_ZALLET_IMAGE`, but do not switch those to a moving tag unless you have checked the tag keeps the variant and platform support Z3 expects.

---

### Q: Which "indexer" does Z3 use, and does Zebra need the `indexer` build feature?

The default Z3 stack does not require Zebra's `indexer` build feature or its indexer gRPC listener. Z3 runs the `zallet-zaino` wallet backend, which reads Zebra through its regular JSON-RPC endpoint, while the optional `indexer` Compose profile starts the standalone Zaino service.

Several settings use the same word for different capabilities:

| Name | What it does | Changes Zebra's stored state? | Required by default Z3? |
|------|--------------|:-----------------------------:|:-----------------------:|
| Compose `--profile indexer` | Starts the standalone Zaino service for lightwalletd-compatible clients | No | No |
| Zallet's `[indexer]` section | Configures how Z3's `zallet-zaino` process reaches Zebra over JSON-RPC | No | Yes |
| Zebra's `rpc.indexer_listen_addr` | Starts the `zebra.indexer.rpc.Indexer` gRPC listener in Zebra 6.2 | No | No |
| Zebra's Cargo `indexer` feature | Adds persistent indexes that map spent outpoints and revealed nullifiers to spending transactions | Yes | No |

The gRPC listener reads Zebra's existing blocks and streams chain-tip, non-finalized-state, and mempool changes. You can enable it on a state directory or restored snapshot that Zebra previously opened without the listener; it does not change the database format, add column families, or backfill data. Set the listener in the operator-local `.env`:

```dotenv
ZEBRA_RPC__INDEXER_LISTEN_ADDR=0.0.0.0:8155
```

Then recreate Zebra:

```bash
docker compose --env-file .env.<network> up -d zebra
```

Containers attached to the Z3 network can then connect to `zebra:8155`. Z3 does not publish this unauthenticated, plaintext endpoint to the host; add an operator-local Compose port mapping only when a host-side client needs it, and do not expose it to an untrusted network.

The alternative direct-state Zallet backend is different. It shares Zebra's state directory, follows the non-finalized tip over the gRPC listener, and requires a Zebra binary built with the Cargo `indexer` feature. Enabling that build feature against an existing database checks and backfills its persistent spending indexes, so it can make the next startup expensive. Z3 deliberately uses `zallet-zaino` instead, which needs neither the shared state directory nor those additional Zebra indexes.

---

## For developers and testers

### Q: How do per-network compose overrides work?

Overrides are opt-in. A fresh clone boots with no override file, so nothing breaks before you run any setup.

- **Mainnet:** Compose natively auto-loads `docker-compose.override.yml` when it is present and you pass no `-f` or `COMPOSE_FILE`. An absent file is not an error.
- **Testnet:** No network overlay exists; `.env.testnet` sets `COMPOSE_FILE=docker-compose.yml`, so the stack renders on a fresh clone. To add per-host customizations (pinning Zebra to `linux/arm64`, adding `deploy.resources.limits`), create `docker-compose.testnet.override.yml` and load it explicitly, either by passing `-f docker-compose.yml -f docker-compose.testnet.override.yml`, or by appending the override to `COMPOSE_FILE` in your operator-local `.env`.
- **Regtest:** `.env.regtest` sets `COMPOSE_FILE=docker-compose.yml:docker-compose.regtest.yml` to layer the regtest overlay (adds `rpc-router` and regtest-only settings) on a fresh clone. Per-host customizations work the same way as testnet: create `docker-compose.regtest.override.yml` and either pass it with `-f` or append it to `COMPOSE_FILE`.

The compose merge order is left-to-right, so the override comes last and wins. The live override file is gitignored, so `git pull` never touches it.

---

### Q: Why doesn't `DOCKER_PLATFORM` in my `.env` take effect?

Because `docker compose --env-file .env.<network>` *replaces* the auto-loaded `.env` for variable interpolation rather than layering on top of it. When you use `--env-file`, anything set only in `.env` is ignored for `${DOCKER_PLATFORM:-linux/amd64}` substitution. This is documented inside `.env` itself and in [docs/contract.md → How env is loaded](contract.md), but it bites everyone at least once.

Two reliable workarounds:

```bash
# (a) export before the call (shell env beats env-file in compose precedence)
export DOCKER_PLATFORM=linux/arm64
docker compose --env-file .env.mainnet up -d

# (b) pass .env as a second --env-file (loaded after the network one, so its values win)
docker compose --env-file .env.mainnet --env-file .env up -d
```

The mainnet stack also has a third path: `docker-compose.override.yml` (gitignored, auto-loaded for mainnet only) can hold an explicit `services.zebra.platform: linux/arm64`. That bypasses env-var interpolation entirely. For testnet and regtest the override file isn't auto-loaded; see the overrides question above.

---

### Q: Why is my Zebra container running under emulation on Apple Silicon?

The default `Z3_ZEBRA_IMAGE` is multi-arch and resolves to native arm64 on Apple Silicon. If `uname -m` inside the Zebra container reports `x86_64` instead of `aarch64`, you've either pinned `Z3_ZEBRA_IMAGE` to an amd64-only tag or exported `DOCKER_PLATFORM=linux/amd64`. Emulation pushes Halo2/Groth16 verification past its internal deadline and surfaces as `Transaction(InternalDowncastError("...Elapsed(())"))` followed by chain-tip sync stalls.

Confirm what's actually running:

```bash
docker exec z3-mainnet-zebra-1 uname -m              # aarch64 = native, x86_64 = emulated
docker top z3-mainnet-zebra-1 -o cmd | head -3       # /usr/bin/qemu-x86_64 wrapper = emulated
```

Zaino is pinned to amd64 by default (its upstream image publishes amd64 only) and runs under emulation; the workload is light enough that the CPU drain is barely noticeable next to Zebra's verifier. Zallet is multi-arch and runs natively.

---

### Q: Can I run Zaino natively on Apple Silicon?

Not from the pinned tag. The default Zaino image publishes `linux/amd64` only (declared in [`z3-contract.yaml`](../z3-contract.yaml) under `image_platforms:`). Confirm with `docker buildx imagetools inspect <image>`. The `unknown/unknown` entries in that output are OCI attestation manifests (SBOM/provenance), not real platform variants.

Two ways forward if you need native arm64:

1. **Build locally.** Fetch the upstream source with `scripts/vendor.sh zaino`, then build with the opt-in overlay: `DOCKER_PLATFORM=linux/arm64 docker compose -f docker-compose.yml -f docker-compose.build.yml build zaino`.
2. **Wait for the upstream tag to gain a multi-arch publish, then bump the pin.** Existing tags never gain new platform variants after the fact; only new tags do.

Leaving Zaino under emulation is fine in practice; the workload is light compared to Zebra's verifier, which runs natively. Zaino only runs under the `indexer` profile, so the default stack is unaffected either way.

Zaino's canonical upstream is [zingolabs/zaino](https://github.com/zingolabs/zaino), published to Docker Hub as `zingodevops/zainod` (matching the daemon binary name). `zingodevops/zaino` is an alias publishing identical digests.

---

### Q: Why does `docker image inspect` report a different architecture than what's running?

Because `docker image inspect <tag>` returns metadata for whichever variant your local store currently has cached under that tag, not the variant the running container was launched from. On an arm64 host the local cache often holds the arm64 metadata for a multi-arch tag even when a `platform: linux/amd64`-pinned container is actively running the amd64 variant out of the same manifest list. The tag → arch mapping is not the container → arch mapping.

For the actual running architecture, use runtime signals:

```bash
docker exec <container> uname -m                                  # reports x86_64 or aarch64
docker top <container> -o cmd | head -3                           # qemu-x86_64 wrapper = emulated
docker exec <container> sh -c 'od -An -tx1 -N20 /path/to/binary'  # ELF e_machine at offset 0x12
```

The ELF `e_machine` field at offset `0x12` is `0x3e` for x86_64 and `0xb7` for aarch64. That's the definitive answer when uname or `/proc` aren't available.

---

### Q: Why does my Zebra slow down when I add a heavy local RPC consumer?

Because Zebra serves block fetches and indexer streaming from the same Tokio worker pool that drives consensus block verification. There is no built-in per-client RPC rate limit and no priority queue between request handlers and the verifier. A bulk indexer in catch-up mode (Zinder, lightwalletd, a fresh Zaino) with high `fetch_concurrency` can sustain enough RPC pressure to slow tip sync, and in extreme cases push transaction verification past its internal deadline.

The CPU saturation is usually the consumer's choice, not Zebra's: turn the consumer's parallelism down before you reach for compose-level limits. For an indexer that's behind, a `fetch_concurrency` in the low single digits while it catches up is much friendlier than the defaults most clients ship with.

If you can't control the consumer, the next lever is compose-level CPU limits (the resource-limits question under [For operators](#q-why-is-my-container-free-to-use-all-of-my-hosts-cpu-and-ram)) so the consumer can never starve the verifier.

---

### Q: Why does regtest use username/password instead of cookie auth?

Because regtest is meant to look like classic local dev, where username/password auth is the convention every existing tutorial and client library assumes. The regtest overlay (`docker-compose.regtest.yml`) disables Zebra's cookie auth and adds an `rpc-router` sidecar that authenticates with `zebra` / `zebra` against Zebra, so the same RPC client works without juggling cookie files.

Cookie auth stays the default for mainnet and testnet, where Zallet (and Zaino under the indexer profile) reads the shared cookie volume directly. See [docs/regtest.md](regtest.md) for the full regtest workflow and the curl/grpcurl examples that use the regtest credentials.

---

## Where to file something that isn't here

If you hit a behavior that looks wrong and the FAQ doesn't cover it, the fastest path to triage is:

1. **Check the container's actual runtime state** (the `uname -m` / `docker top` / ELF-header trio in the architecture-detection question above). Most "why is this slow?" reports trace back to a platform or resource-limit assumption that wasn't true.
2. **Look at the compose-resolved config**, not the source YAML: `docker compose --env-file .env.<network> config <service>` shows you the variables after interpolation, which is what Docker actually receives.
3. **Open an issue** with the resolved config, the runtime signals, and the symptom. Without the resolved config, every triage round restarts from "is your env var actually set."
