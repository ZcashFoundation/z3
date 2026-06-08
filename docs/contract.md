# Z3 Platform Contract

This document is the human-facing version of [`z3-contract.yaml`](../z3-contract.yaml). The YAML is the source of truth for integration identifiers and is validated against [`z3-contract.schema.json`](../z3-contract.schema.json). This doc explains what each identifier means, what consumers can rely on, and what is explicitly out of scope.

For copy-paste integration examples, see [`docs/integrations/`](integrations/).

## Stability promise

Identifiers in the contract are SemVer-stable. The shipped contract version is `1.0.0`:

- **Patch** (1.0.x): documentation-only changes; no consumer impact.
- **Minor** (1.x.0): adds optional fields, new env vars, new optional services. Existing consumers continue working.
- **Major** (x.0.0): renames, removed identifiers, or port changes. Existing consumers need to migrate.

Identifiers NOT in this contract (Compose service container names, internal config-rs env vars, monitoring volumes, scrape labels) are z3's implementation. They can change without a contract bump.

### Contract version and image pins

The contract version (`z3-contract.yaml` → `contract_version`) is the SemVer-stable API surface bumped per the policy above. Image pins are not part of the contract: they live as `${VAR:-tag}` defaults in `docker-compose.yml` and bump independently of the contract version (a Zebra patch release `4.4.1` → `4.4.2` does not require a contract bump). Operators override any pin with `Z3_ZEBRA_IMAGE`, `Z3_ZAINO_IMAGE`, `Z3_ZALLET_IMAGE`, or `Z3_ZCASHD_IMAGE`. Platform constraints per image live in `z3-contract.yaml` under `image_platforms:`.

## What z3 publishes

### Networks

Z3 runs as one of three Compose projects, one per Zcash network. The full set of identifiers (project name, external network name, `Z3_NETWORK` value) lives in `z3-contract.yaml` under `networks.<name>`.

`Z3_NETWORK` is PascalCase (it passes through to Zebra's `serde` deserializer). `COMPOSE_PROJECT_NAME` is lowercase (Docker Compose accepts only lowercase letters, digits, dashes, and underscores). Both are required; the `.env.<network>` files set both.

### Volumes

Every per-network resource is a named Docker volume with an explicit `name:` declaration, so it is not subject to Compose's project-prefix behavior. Names follow the pattern `z3-<network>-<suffix>` (e.g., `z3-mainnet-cookie`); the full set is in `z3-contract.yaml` under `networks.<name>.volumes`.

Of these, `cookie` is part of the consumer-facing attachment surface only when the network's `rpc_auth.mode` is `cookie` (mainnet and testnet). Regtest carries the named volume as an internal Compose artifact, but its `rpc_auth.mode` is `username_password`; consumers should not mount `z3-regtest-cookie` expecting a readable RPC cookie. The other volumes are z3's storage and should not be mounted. The `zcashd` volume is profile-gated (only created under `--profile zcashd`); the YAML marks it with `profile: zcashd`.

### In-network DNS

Inside the Docker network, services resolve at their bare service name (`zebra`, `zaino`, `zallet`, and `zcashd` under `--profile zcashd`). The YAML's `service_dns:` block carries the full list and marks `zcashd` with `profile: zcashd`.

No per-network suffix: the network itself is the discriminator. A consumer attached to `z3-testnet` uses `http://zebra:18232`; on `z3-mainnet` it uses `http://zebra:8232`.

### Cookie file

The path is `/var/run/auth/.cookie` on every container that uses cookie auth. Mainnet and testnet publish `rpc_auth.mode: cookie`; Z3's Zebra writes the cookie, and Z3's Zaino, Zallet, and any consumer attached to the cookie volume mount it read-only at this path.

Regtest is the exception: it publishes `rpc_auth.mode: username_password`, sets `ZEBRA_RPC__ENABLE_COOKIE_AUTH=false`, and the regtest overlay removes the cookie mount from Zaino and Zallet. Zebra does not guarantee `/var/run/auth/.cookie` on regtest. Regtest consumers should use the documented username/password path, usually through the rpc-router defaults (`zebra` / `zebra`) or the per-service regtest config.

### Port matrix

Container ports follow Zebra's per-network defaults from upstream (`zebra-chain/src/parameters/network.rs:239`, `zebra-rpc/src/config/rpc.rs:17-47`). Host ports are explicit and globally unique across all published services and optional profiles, so all three networks coexist on one host. The full matrix (including the `monitoring` profile) is in `z3-contract.yaml` under `networks.<name>.ports`.

For non-mainnet networks, host ports for services without an upstream per-network convention (Zaino, Zallet, monitoring) use a +10000 offset relative to mainnet, with two exceptions. Regtest Zebra RPC moves to host `29232` because `28232` is already mainnet Zallet's host port. Zebra's metrics port stays in-network only on every network (no host publication).

Regtest also uses Zebra's testnet container-port defaults.

### Healthchecks

Per-service health surface. The YAML's `healthchecks:` block carries the per-service transport, port, and endpoint with `profile:` gating for `zcashd`.

Operational details worth knowing:

- **Zaino's check is a TCP probe on the gRPC port.** It confirms a listener exists; it does not validate the gRPC handler. Do not use it for production routing decisions.
- **Zallet has no healthcheck.** Its distroless image has no shell or probe binary, so `depends_on: condition: service_healthy` against Zallet hangs. Gate on Zebra's `/ready` instead and assume Zallet follows.
- **`/ready` is sync-strict; `/healthy` is peer-only.** `/healthy` returns success when Zebra has at least `ZEBRA_HEALTH__MIN_CONNECTED_PEERS` peers; `/ready` additionally requires sync within `ZEBRA_HEALTH__READY_MAX_BLOCKS_BEHIND` of tip. Use `/ready` for production; the tracked `docker-compose.override.yml.example` flips to `/healthy` for development.

Inside the Docker network, consumers wait on Zebra via `depends_on` with `condition: service_healthy`. Outside the network, consumers poll the published health port (per-network number in `z3-contract.yaml`).

### Env var schema

Three namespaces keep stack-level settings separate from service-native settings.

**`Z3_*` (stack-level settings).** Used for host port mappings, image pins, volume path overrides, the per-service `RUST_LOG` split, multi-network selection (`Z3_NETWORK`, `Z3_CONFIG_DIR`), and scoping wrappers such as `Z3_REGTEST_RPC_ROUTER_USER`. Image-pin defaults are `${VAR:-tag}` fallbacks in `docker-compose.yml`.

**Service-native names (passed through as-is).** Used when the underlying service has a documented convention. Operators map straight from the service's docs without learning a z3 wrapper. Examples: `GF_SECURITY_ADMIN_PASSWORD` (Grafana), `ZAINO_GRPC_SETTINGS__TLS__*` (Zaino config-rs), `ZCASHD_*` (zcashd image entrypoint), `ZEBRA_*` (Zebra config-rs, including `ZEBRA_HEALTH__*`, `ZEBRA_RPC__ENABLE_COOKIE_AUTH`, `ZEBRA_TRACING__*`, `ZEBRA_MINING__MINER_ADDRESS`).

**Ecosystem-standard names (inherited; not part of the z3 contract).** Documented for completeness because operators encounter them in our docs: `COMPOSE_FILE`, `RUST_LOG`, `RUST_BACKTRACE`. The YAML lists them under `ecosystem_vars:`.

**Internal vars (not in the contract).** Z3 sets these inside the compose `environment:` block; operators set the public knobs above instead. Examples: `ZEBRA_RPC__LISTEN_ADDR`, `ZAINO_VALIDATOR_SETTINGS__*`, `ZCASHD_RPCBIND`. Also hardcoded in the compose (no operator override): Zaino, Zallet, and zcashd container ports, which do not differ per network.

For the canonical machine-readable inventory (every variable, its namespace tag, and profile gating), see [`z3-contract.yaml`](../z3-contract.yaml) under `env_vars:` and `ecosystem_vars:`.

### Profiles

Two Compose profiles are available across every network: `monitoring` (Prometheus, Grafana, Jaeger, AlertManager) and `zcashd` (the optional zcashd comparator; requires `Z3_ZCASHD_IMAGE`). Enable with `docker compose --env-file .env.<network> --profile <profile> up -d`. Profile-gated identifiers in the YAML carry an explicit `profile:` field.

## What z3 does NOT publish

These are explicitly OUT of the contract; they may change without a major version bump:

- **Container names** (e.g., `z3-mainnet-zebra-1`). Compose autogenerates them; consumers should reference services by their in-network DNS name, not the container name.
- **Per-network config file contents** (the live `config/<network>/zallet.toml`, `config/<network>/zaino.toml`). These are local files (see "File ownership" below); their contents are not part of the consumer-facing contract.
- **Internal env vars** (`ZEBRA_RPC__LISTEN_ADDR`, `ZAINO_VALIDATOR_SETTINGS__*`, `ZCASHD_RPCBIND`, etc.). Z3 sets them inside the compose `environment:` block; operators set the public knobs documented above instead.
- **Monitoring identifiers** (Prometheus job labels, Grafana datasource UIDs, dashboard UIDs). Internal.
- **Compose secrets and configs** (`zaino_tls_cert`, `zaino_tls_key`, `prometheus_config`). Internal.

## File ownership

Files in this repository fall into two categories. The separation lets operators iterate locally without merge conflicts and lets maintainers ship template updates without disturbing operator copies.

### Maintainer-owned (tracked in git)

These files are tracked defaults. Operators should not edit them; doing so creates merge conflicts on repository updates.

| Path | Purpose |
|------|---------|
| `docker-compose.yml`, `docker-compose.testnet.yml`, `docker-compose.regtest.yml` | Stack topology. Override via `docker-compose.override.yml` (see below). |
| `z3-contract.yaml`, `z3-contract.schema.json`, `docs/contract.md` | The contract, its schema, and this guide. |
| `.env.example` | Reference for every public env var. |
| `.env.mainnet`, `.env.testnet`, `.env.regtest` | Per-network defaults. Override via `.env`. |
| `config/<network>/zallet.toml.example` | Zallet config template. |
| `config/<network>/zaino.toml.example` | Zaino config template. |

### Local (gitignored)

These files are created locally by `scripts/setup-network.sh <network>` and edited freely. Repository updates never overwrite them.

| Path | Created by | Purpose |
|------|------------|---------|
| `.env` | Local user | Per-host overrides; see "How `.env` is loaded" below. |
| `docker-compose.override.yml` | Local user (template in `.example`) | Per-host overrides for compose service definitions. Auto-loaded for mainnet. |
| `docker-compose.testnet.override.yml` | Local user (optional) | Per-host testnet overrides. **Not auto-loaded;** add to `COMPOSE_FILE` explicitly. |
| `config/<network>/zallet.toml` | `setup-network.sh` (cp from `.example`) | Active Zallet config. Edit to taste. |
| `config/<network>/zaino.toml` | `setup-network.sh` (cp from `.example`) | Active Zaino config. Edit to taste. |
| `config/<network>/zallet_identity.txt` | `setup-network.sh` (`rage-keygen`) | Per-operator wallet encryption key. Back this up. |
| `config/tls/zaino.crt`, `config/tls/zaino.key` | `setup-network.sh` (`openssl`) | TLS cert for Zaino's gRPC endpoint. |

After `git pull`, diff your live `.toml` against the refreshed `.example`; apply any desired changes by hand:

```bash
diff config/mainnet/zallet.toml config/mainnet/zallet.toml.example
```

### How `.env` is loaded

Docker Compose auto-loads `.env` from the working directory ONLY when no `--env-file` flag is given. The documented invocation pattern (`docker compose --env-file .env.<network> up -d`) replaces that auto-load: variables in `.env.<network>` are used for compose-level interpolation, and `.env` is not consulted.

To make values in `.env` take effect under the `--env-file` pattern, use one of:

```bash
# Option 1: Pass .env as a second --env-file (later wins for collisions)
docker compose --env-file .env.mainnet --env-file .env up -d

# Option 2: Export in the shell before running compose
export Z3_JAEGER_OTLP_GRPC_PORT=14317
docker compose --env-file .env.mainnet up -d

# Option 3: Use a wrapper alias / script that always passes both files
```

Variables consumed through a service-level `env_file:` directive are still loaded from `.env` regardless of `--env-file`. Zebra uses this for optional config-rs settings. These variables reach the container's environment but do not influence compose's `${VAR}` interpolation.

## Versioning

`contract_version` in `z3-contract.yaml` is the SemVer for the API surface, decoupled from the z3 git tag. A z3 release may keep the same contract version or bump it for contract changes such as renamed identifiers, removed fields, or new ports. Image pins are not versioned: they're `${VAR:-tag}` defaults in `docker-compose.yml` that bump per upstream release.

When the contract bumps, z3 publishes:

- A `CHANGELOG.md` entry naming what changed.
- Release notes describing any required operator and consumer updates.
- A new SemVer tag on the z3 repository.

Consumers should pin to a contract major version and only adopt minor or patch bumps automatically.

## Validation

The repository CI validates this contract on every PR. The job parses `z3-contract.yaml`, runs `docker compose --env-file .env.<network> config` for each network, and asserts that every documented identifier (network name, volume name, port, env var) exists in the resolved compose output. A drift between this doc and the compose file is a CI failure.

Operators can run the same validation locally:

```bash
./scripts/validate-contract.py         # port matrix and volume names per network
./scripts/validate-contract-parity.py  # env var inventory across compose and .env.example
```

Consumers in any language can validate `z3-contract.yaml` against the shipped JSON Schema:

```bash
# Example using `check-jsonschema` (any JSON Schema validator works).
pip install check-jsonschema pyyaml
python -c 'import yaml,json,sys; json.dump(yaml.safe_load(open("z3-contract.yaml")), sys.stdout)' \
  | check-jsonschema --schemafile z3-contract.schema.json /dev/stdin
```
