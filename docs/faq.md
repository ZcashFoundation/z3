# Operator FAQ

Answers to behaviors that look like bugs but are working as designed, plus a few real footguns that aren't obvious from reading the compose file. If you're looking for *how the stack is shaped* (compose merge rules, healthcheck design, security hardening) read [docker-architecture.md](docker-architecture.md) instead; this doc is for *why is the thing I'm running behaving this way*.

When an entry says "see README", it means the prescriptive fix already lives there and we don't want to drift from it; this doc only adds the diagnostic context.

---

## Q: Why is my Zebra container running under emulation on Apple Silicon?

The default `Z3_ZEBRA_IMAGE` is multi-arch and resolves to native arm64 on Apple Silicon. If `uname -m` inside the Zebra container reports `x86_64` instead of `aarch64`, you've either pinned `Z3_ZEBRA_IMAGE` to an amd64-only tag or exported `DOCKER_PLATFORM=linux/amd64`. Emulation pushes Halo2/Groth16 verification past its internal deadline and surfaces as `Transaction(InternalDowncastError("...Elapsed(())"))` followed by chain-tip sync stalls.

Confirm what's actually running:

```bash
docker exec z3-mainnet-zebra-1 uname -m              # aarch64 = native, x86_64 = emulated
docker top z3-mainnet-zebra-1 -o cmd | head -3       # /usr/bin/qemu-x86_64 wrapper = emulated
```

Zaino and Zallet are pinned to amd64 by default (their upstream images publish amd64 only) and run under emulation; the workload is light enough that the CPU drain is barely noticeable next to Zebra's verifier.

---

## Q: Why doesn't `DOCKER_PLATFORM` in my `.env` take effect?

Because `docker compose --env-file .env.<network>` *replaces* the auto-loaded `.env` for variable interpolation rather than layering on top of it. Anything you only put in `.env` is invisible to `${DOCKER_PLATFORM:-linux/amd64}` substitution when the invocation uses `--env-file`. This is documented inside `.env` itself and in [docs/contract.md → How env is loaded](contract.md), but it bites everyone at least once.

Two reliable workarounds:

```bash
# (a) export before the call (shell env beats env-file in compose precedence)
export DOCKER_PLATFORM=linux/arm64
docker compose --env-file .env.mainnet up -d

# (b) pass .env as a second --env-file (loaded after the network one, so its values win)
docker compose --env-file .env.mainnet --env-file .env up -d
```

The mainnet stack also has a third path: `docker-compose.override.yml` (gitignored, auto-loaded for mainnet only) can hold an explicit `services.zebra.platform: linux/arm64`. That bypasses env-var interpolation entirely. For testnet and regtest the override file isn't auto-loaded; see the next question.

---

## Q: How do per-network compose overrides work?

`docker-compose.<network>.override.yml` is the per-host customization file for each network (e.g., pinning Zebra to `linux/arm64` on Apple Silicon, adding `deploy.resources.limits`). All three networks auto-load it when present:

- **Mainnet:** Compose auto-loads `docker-compose.override.yml` when no `-f` or `COMPOSE_FILE` is set (this is Compose's native behavior).
- **Testnet:** `.env.testnet` sets `COMPOSE_FILE=docker-compose.yml:docker-compose.testnet.yml:docker-compose.testnet.override.yml`. The override file always exists because `scripts/setup-network.sh testnet` copies the `.example` placeholder into place on first run.
- **Regtest:** same pattern as testnet (`.env.regtest` + `docker-compose.regtest.override.yml`).

Workflow:

1. Run `scripts/setup-network.sh <network>` once. It creates `docker-compose.<network>.override.yml` as an empty `services: {}` placeholder if missing.
2. Edit the live file to add your customizations.
3. `docker compose --env-file .env.<network> up -d` auto-loads it.

The compose merge order is left-to-right, so the override comes last and wins.

The live override file is gitignored; the tracked template lives next to it as `.example`. `git pull` never touches your live copy.

---

## Q: Why does `docker image inspect` report a different architecture than what's running?

Because `docker image inspect <tag>` returns metadata for whichever variant your local store currently has cached under that tag, not the variant the running container was launched from. On an arm64 host the local cache often holds the arm64 metadata for a multi-arch tag even when a `platform: linux/amd64`-pinned container is actively running the amd64 variant out of the same manifest list. The tag → arch mapping is not the container → arch mapping.

For the actual running architecture, use runtime signals:

```bash
docker exec <container> uname -m                                  # reports x86_64 or aarch64
docker top <container> -o cmd | head -3                           # qemu-x86_64 wrapper = emulated
docker exec <container> sh -c 'od -An -tx1 -N20 /path/to/binary'  # ELF e_machine at offset 0x12
```

The ELF `e_machine` field at offset `0x12` is `0x3e` for x86_64 and `0xb7` for aarch64. That's the definitive answer when uname or `/proc` aren't available.

---

## Q: Why is my Zebra container marked `unhealthy` right after start?

That's the `/ready` probe doing its job, not a fault. `/ready` requires the node to have at least `ZEBRA_HEALTH__MIN_CONNECTED_PEERS` (default `1`) and to be within `ZEBRA_HEALTH__READY_MAX_BLOCKS_BEHIND` (default `2`) of the network tip. A fresh start from a cold chain, or a restart on a cache that's a few minutes behind, will report `unhealthy` until both thresholds are met.

For development, `/healthy` is a looser signal that only checks peer connectivity. The tracked `docker-compose.override.yml.example` flips the healthcheck to `/healthy` so Zaino and Zallet can start without waiting for full sync. Use it for dev, never for production where you want consumers to wait for a synced node.

The poller `scripts/check-zebra-readiness.sh` exists exactly because you should not run `docker compose up -d` (which starts Zaino/Zallet) until Zebra reports `/ready` in production. README → Quick start step 3 explains the two-phase boot.

---

## Q: Can I run Zaino or Zallet natively on Apple Silicon?

Not from the pinned tags. The default Zaino and Zallet images publish `linux/amd64` only (declared in [`z3-contract.yaml`](../z3-contract.yaml) under `image_platforms:`). Confirm with `docker buildx imagetools inspect <image>`. The `unknown/unknown` entries in that output are OCI attestation manifests (SBOM/provenance), not real platform variants.

Two ways forward if you need native arm64:

1. **Build locally.** `docker-compose.yml` declares `build:` contexts pointing at the `./zaino` and `./zallet` submodules, so `DOCKER_PLATFORM=linux/arm64 docker compose build zaino zallet` produces local arm64 images.
2. **Wait for the upstream tag to gain a multi-arch publish, then bump the pin.** Existing tags never gain new platform variants after the fact; only new tags do.

Leaving these two services under emulation is fine in practice; the workload is light compared to Zebra's verifier, which runs natively.

Zaino's canonical upstream is [zingolabs/zaino](https://github.com/zingolabs/zaino), published to Docker Hub as `zingodevops/zainod` (matching the daemon binary name). `zingodevops/zaino` is an alias publishing identical digests.

---

## Q: Why does my Zebra slow down when I add a heavy local RPC consumer?

Because Zebra serves block fetches and indexer streaming from the same Tokio worker pool that drives consensus block verification. There is no built-in per-client RPC rate limit and no priority queue between request handlers and the verifier. A bulk indexer in catch-up mode (Zinder, lightwalletd, a fresh Zaino) with high `fetch_concurrency` can sustain enough RPC pressure to slow tip sync, and in extreme cases push transaction verification past its internal deadline.

The CPU saturation is usually the consumer's choice, not Zebra's: turn the consumer's parallelism down before you reach for compose-level limits. For an indexer that's behind, a `fetch_concurrency` in the low single digits while it catches up is much friendlier than the defaults most clients ship with.

If you can't control the consumer, the next lever is compose-level CPU limits (next question) so the consumer can never starve the verifier.

---

## Q: Why is my container free to use all of my host's CPU and RAM?

Because `docker-compose.yml` doesn't set `deploy.resources.limits` on any service. The choice is deliberate for a node platform: a constrained limit that makes sense on a 4-core laptop will silently throttle a 32-core production host, and the bound that's right for one operator is wrong for the next.

If you want to bound a single noisy service (a bulk indexer, a comparator, a one-off backfill) without hand-tuning everything else, add the limit in your operator-local override file rather than the tracked compose:

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

## Q: Is zcashd part of the default stack?

No. zcashd is behind a Compose profile (`--profile zcashd`) and is opt-in. The plain `docker compose up -d` invocation does not start it, does not touch its data volume, and does not bind its host port. You enable it explicitly when you want a comparator for behavior diff:

```bash
docker compose --env-file .env.mainnet --profile zcashd up -d zcashd
```

The image is hardcoded to `linux/amd64` because the upstream zcashd image publishes amd64 only (declared in [`z3-contract.yaml`](../z3-contract.yaml) under `image_platforms:`). On Apple Silicon it runs under emulation regardless of your `DOCKER_PLATFORM` setting. That's intentional: otherwise an arm64-pinned operator would see image-pull failures on a service they may never enable. README → Optional zcashd comparator covers the three-network invocation matrix.

---

## Q: Why does regtest use username/password instead of cookie auth?

Because regtest is meant to look like zcashd-style local dev, where username/password auth is the convention every existing tutorial and client library assumes. The regtest overlay (`docker-compose.regtest.yml`) disables Zebra's cookie auth and adds an `rpc-router` sidecar that authenticates with `zebra` / `zebra` against both Zebra and zcashd, so the same RPC client works against either backend during comparator runs.

Cookie auth stays the default for mainnet and testnet, where Zaino and Zallet read the shared cookie volume directly. See [docs/regtest.md](regtest.md) for the full regtest workflow and the curl/grpcurl examples that use the regtest credentials.

---

## Where to file something that isn't here

If you hit a behavior that looks wrong and the FAQ doesn't cover it, the fastest path to triage is:

1. **Check the container's actual runtime state** (the `uname -m` / `docker top` / ELF-header trio in the architecture-detection question above). Most "why is this slow?" reports trace back to a platform or resource-limit assumption that wasn't true.
2. **Look at the compose-resolved config**, not the source YAML: `docker compose --env-file .env.<network> config <service>` shows you the variables after interpolation, which is what Docker actually receives.
3. **Open an issue** with the resolved config, the runtime signals, and the symptom. Without the resolved config, every triage round restarts from "is your env var actually set."
