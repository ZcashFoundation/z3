# Docker Compose Architecture

This document explains the Docker Compose patterns and runtime behavior used in the z3 stack. It is a reference for contributors and operators who need to understand how the stack is structured.

For the public contract (network names, volume names, port matrix), see [`contract.md`](contract.md).

## Overview

```text
docker-compose.yml              Base stack (Zebra + Zaino + Zallet + optional profiles)
docker-compose.regtest.yml      Regtest overlay (structural differences only)
docker-compose.build.yml        Opt-in source-build overlay (scripts/vendor.sh)
.env.mainnet                    Mainnet selection + canonical ports
.env.testnet                    Testnet selection + offset ports
.env.regtest                    Regtest selection + overlay loader
.env.example                    Reference for every public override
.env                            Operator-specific overrides (gitignored, optional)
config/mainnet/                 Mainnet Zallet + Zaino configs + identity file
config/testnet/                 Testnet equivalents
config/regtest/                 Regtest equivalents
scripts/                        Operational scripts (regtest-init, fix-permissions, etc.)
```

The core principle: **`docker-compose.yml` is self-sufficient for mainnet**. Every variable uses `${VAR:-default}` syntax, so `docker compose up` works on a fresh clone with zero configuration files. The per-network env files exist to switch networks; `.env` is purely optional operator overrides.

## Defaults-in-compose pattern

Every variable reference in `docker-compose.yml` includes a default value:

```yaml
image: ${Z3_ZEBRA_IMAGE:-zfnd/zebra:latest}
environment:
  ZEBRA_NETWORK__NETWORK: ${Z3_NETWORK:-Mainnet}
volumes:
  - ${Z3_CHAIN_DATA_PATH:-chain}:/home/zebra/.cache/zebra
ports:
  - "${Z3_ZEBRA_HOST_RPC_PORT:-8232}:${Z3_ZEBRA_RPC_PORT:-8232}"
```

Docker Compose resolves `${VAR:-default}` as: use `VAR` if set and non-empty, otherwise use `default`. Values come from (highest precedence first):

1. Shell environment variables (`Z3_ZEBRA_IMAGE=custom docker compose up`)
2. `--env-file <path>` arguments
3. `.env` file in the project root (auto-loaded)
4. The `:-default` fallback in the compose file

The mainnet env file (`.env.mainnet`) sets only `COMPOSE_PROJECT_NAME`, `Z3_NETWORK`, and `Z3_CONFIG_DIR` because the compose defaults already match mainnet. Testnet and regtest env files set additional overrides (container ports, host ports, network selection) to switch the stack.

## Multi-environment support

### Per-network Compose projects

Z3 runs as one of three Compose projects: `z3-mainnet`, `z3-testnet`, `z3-regtest`. Each is a separate logical instance with its own resources. Project name comes from `COMPOSE_PROJECT_NAME` in the env file.

| Network | Project | Selected via |
|---------|---------|--------------|
| Mainnet | `z3-mainnet` | `docker compose --env-file .env.mainnet up` |
| Testnet | `z3-testnet` | `docker compose --env-file .env.testnet up` |
| Regtest | `z3-regtest` | `docker compose --env-file .env.regtest up` |

Compose's native project boundary handles isolation: each project has its own containers, network, and volumes. Mainnet, testnet, and regtest can run concurrently on one host without collisions because their published host ports differ. Testnet keeps Zebra's canonical host ports; regtest uses explicit host ports where a simple offset would collide with another service.

### Explicit `name:` declarations

Compose's default behavior prefixes every volume and network with `${COMPOSE_PROJECT_NAME}_`. For internal services this is fine; for the public contract identifiers that consumers attach to, it is brittle: a project rename silently breaks every consumer.

Z3 declares external-facing resources with explicit `name:`:

```yaml
volumes:
  chain:
    name: ${COMPOSE_PROJECT_NAME:-z3-mainnet}-chain
  cookie:
    name: ${COMPOSE_PROJECT_NAME:-z3-mainnet}-cookie

networks:
  default:
    name: ${COMPOSE_PROJECT_NAME:-z3-mainnet}
```

The `name:` field is documented as "used as-is and not scoped with the project name" (Docker Compose reference). This makes `z3-testnet-cookie` and `z3-testnet` the stable external identifiers consumers reference via `external: true, name: ...`. Renaming the Compose project would not affect them.

Volumes and networks not part of the contract (Prometheus data, Compose configs) keep the default prefix; they are internal.

### `COMPOSE_FILE` for overlay loading

`.env.regtest` includes `COMPOSE_FILE` so the regtest overlay is loaded with
the base compose:

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.regtest.yml
```

When run with `--env-file .env.regtest`, Compose loads both files and merges them. The colon-separated list is processed left to right; later files override earlier ones. The regtest overlay contains the peerless healthcheck, username/password auth on Zaino, and the optional rpc-router. Testnet needs no overlay: `.env.testnet` sets `COMPOSE_FILE=docker-compose.yml` and selects the network through `Z3_NETWORK=Testnet`.

### Compose file merge rules

When an overlay defines the same service as the base, attributes merge as follows:

| Attribute type | Merge behavior |
|----------------|---------------|
| Scalars (`image`, `command`) | Override replaces |
| `environment` | Merge by key name; override wins on conflict |
| `volumes` (service-level) | Merge by mount target path; same target = override wins |
| `ports` | Append |
| `healthcheck` | Override replaces entirely |
| `build.args` | Merge by key name; override wins on conflict |

### `!override` YAML tag

Standard YAML merge can add and overwrite keys but cannot *remove* them. Docker Compose v2.24.4+ supports the `!override` tag used here:

```yaml
services:
  zaino:
    environment: !override
      RUST_LOG: info
      ZAINO_NETWORK: Regtest
      # only regtest-relevant vars; cookie path from base is dropped
```

`!override` fully replaces the attribute instead of merging. The regtest overlay uses this on Zaino's `environment` to switch from cookie-based authentication (base compose) to username/password authentication (credentials in `config/regtest/zaino.toml`).

A related tag, `!reset`, clears an attribute to its default value. This stack requires Docker Compose v2.24.4 or later for these tags.

## Per-network configuration

### Zallet config files

Zallet's `[indexer]` block hardcodes the validator address it connects to (Zebra's JSON-RPC). Because the JSON-RPC port differs per network (Mainnet 8232, Testnet 18232, Regtest 18232), Z3 ships one Zallet config per network:

```
config/mainnet/zallet.toml      validator_address = "zebra:8232"
config/testnet/zallet.toml      validator_address = "zebra:18232"
config/regtest/zallet.toml      validator_address = "zebra:18232" (username/password auth)
```

The compose mount path is templated:

```yaml
volumes:
  - ${Z3_CONFIG_DIR:-./config/mainnet}/zallet.toml:/etc/zallet/zallet.toml:ro
```

`Z3_CONFIG_DIR` is set per env file (`./config/mainnet`, `./config/testnet`, `./config/regtest`). To change Zallet behavior, edit the per-network file directly.

### Zaino config files

Zaino's config is empty for mainnet and testnet (all settings come from env vars); regtest needs a non-empty file because it uses username/password auth that cannot be set via env vars (Zaino blocks env vars containing "password" for security). The compose mounts `${Z3_CONFIG_DIR}/zaino.toml` for symmetry with Zallet.

### Zallet identity files

Each network has its own age-encryption identity at `config/<network>/zallet_identity.txt`. The file is gitignored. Identities are generated by `scripts/setup-network.sh <network>` (which `scripts/regtest-init.sh` delegates to for regtest). See the README Quick start.

## Extension fields and YAML anchors

### `x-common`: shared service configuration

```yaml
x-common: &common
  cap_drop: [ALL]
  security_opt: [no-new-privileges:true]
```

Services reference this with `<<: *common` for consistent security hardening without repeating the configuration. Logging is intentionally absent (see "Log rotation" below).

Top-level keys starting with `x-` are *extension fields*; Compose ignores them during processing but they serve as anchor sources for YAML reuse.

### Zebra's `setpriv` entrypoint

Zebra's Docker entrypoint starts as root, runs `mkdir` and `chown` to set up mounted volume directories, then uses `setpriv` (part of `util-linux`, included in Debian trixie) to drop to a non-root user. These pre-privilege-drop operations need capabilities that `cap_drop: [ALL]` removes, so Zebra adds back only the five it needs:

```yaml
cap_add: [CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID]
```

Zallet is the only core service pinned directly to a non-root user in Compose (`user: "1000:1000"`). Zaino is not pinned with a Compose `user:` override and has the setup capabilities declared in `docker-compose.yml`, so Zallet's bind-mounted config has the strictest host-file readability requirement.

## Healthchecks

### `start_interval`: two-speed healthchecks

Docker Engine 25.0+ supports `start_interval`, which checks more frequently during startup and then backs off:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://127.0.0.1:8080/ready || exit 1"]
  interval: 30s          # steady-state: every 30s
  start_interval: 5s     # during startup: every 5s
  start_period: 90s      # grace period before failures count
```

During the `start_period`, the check runs every `start_interval` (5s). After the first success or after `start_period` expires, it switches to `interval` (30s). A service that becomes ready in 10 seconds is detected in ~15 seconds instead of waiting up to 120 seconds.

### Zaino: port check instead of process check

Zaino's image (`debian:bookworm-slim`) does not include `curl` or `netcat`. The healthcheck uses bash's built-in TCP socket capability:

```yaml
test: ["CMD-SHELL", "bash -c 'echo > /dev/tcp/127.0.0.1/8137' 2>/dev/null || exit 1"]
```

This verifies the gRPC port is actually accepting connections. The previous check (`zainod --version`) only confirmed the binary existed on disk; it would pass even if the service had crashed after startup.

### Regtest Zebra: RPC check instead of `/ready`

The base compose uses Zebra's `/ready` endpoint, which verifies the node is synced near the network tip. In regtest mode there are no peers and no network tip to sync to, so `/ready` would never succeed. The regtest overlay replaces this with a direct RPC call (`getblockchaininfo`) that confirms the RPC server is responding.

### Development override

`docker-compose.override.yml.example` provides a ready-made override that switches Zebra's healthcheck from `/ready` to `/healthy`, allowing dependent services to start during sync. Copy it to `docker-compose.override.yml` (gitignored) for local development.

## Security hardening

### `cap_drop: [ALL]`

Linux containers receive ~14 capabilities by default (including `CHOWN`, `DAC_OVERRIDE`, `NET_RAW`). Most applications don't need any of them. `cap_drop: [ALL]` removes all capabilities, reducing the attack surface if a container is compromised.

### `security_opt: [no-new-privileges:true]`

Prevents processes inside the container from gaining additional privileges through setuid binaries or capability inheritance. Even if an attacker writes a setuid binary into a writable tmpfs, it won't escalate privileges.

### Log rotation

z3 does not pin a `logging:` driver on any service. A Compose `logging:` block overrides the driver the operator configured on the Docker daemon (journald, local, a remote collector), so forcing `json-file` would silently undo that choice. Bounding log growth is the daemon's job: set a rotating default once in `/etc/docker/daemon.json`, which applies to every container on the host.

```json
{
  "log-driver": "local",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
```

The `local` driver rotates by default and is more efficient than `json-file`. Operators who want per-service control add a `logging:` block in their override file instead.

## Image override variables

All service images are overridable. Compose references each image as `${Z3_<SERVICE>_IMAGE:-<default-tag>}`; the default tags are inline in `docker-compose.yml` itself and bump per upstream release. This allows operators to:

- Pin to a specific version or digest for reproducibility.
- Test a pre-release candidate without editing the compose file.
- Use a private registry mirror in air-gapped environments.
- Run CI with custom-built images via shell variables.

Tags are pinned, never floating (`:latest`). On a consensus-critical node platform a silent major bump on the next `pull` or recreate could fork the operator off the network, so upgrades are deliberate: bump the inline default in a reviewed change, set `Z3_<SERVICE>_IMAGE` to move a single service, or let Renovate (`renovate.json`) raise an auditable bump PR. Dependabot stays scoped to GitHub Actions because it cannot parse the `${VAR:-tag}` default form.

The `Z3_*_IMAGE` prefix marks these as part of the public contract; `z3-contract.yaml` lists the env-var schema in full.

## Environment variable strategy

### Explicit mapping via `environment:`

All services declare their environment variables explicitly in the `environment:` block. This prevents unintended variables from crossing service boundaries. Zallet does not support environment variable configuration at all, so it only receives `RUST_LOG`.

### Zebra's `env_file` exception

Zebra is the only service that also uses `env_file: [{path: ./.env, required: false}]`. Zebra uses config-rs, which auto-reads any `ZEBRA_*` environment variable. Optional config-rs variables like `ZEBRA_TRACING__OPENTELEMETRY_*` cannot be listed in the explicit `environment:` block with empty defaults, because config-rs treats empty strings as values and crashes when parsing `""` as a socket address. `ZEBRA_METRICS__ENDPOINT_ADDR` is the exception: z3 sets a non-empty default so the monitoring profile always has a Zebra scrape target.

The `env_file` passthrough allows these optional variables to reach Zebra only when the operator explicitly sets them in `.env`. When `.env` does not exist, Zebra receives only the explicit `environment:` variables and uses its built-in defaults.

Non-`ZEBRA_*` variables from `env_file` are ignored because config-rs reads only variables that match its configured prefix.

## Cookie-permissions sidecar

Zebra writes the RPC cookie at `/var/run/auth/.cookie` with mode `0600` owned by uid 10001. Z3's consumer-attachment surface includes the cookie volume, so any service or downstream container that mounts it needs to read the cookie.

The base compose includes a small `cookie-permissions` sidecar (`alpine:3` with `cap_add: [FOWNER]`) that polls every 5 seconds and chmods the cookie to `0644` once it appears. The cookie volume is already the consumer attachment surface, so loosening the file mode within that volume does not change the security boundary; anyone with access to mount the volume already has access to the cookie.

Zaino and Zallet depend on the sidecar's healthcheck, so targeted starts such as `docker compose up -d zaino` also start the sidecar and wait until the cookie is readable. On mainnet and testnet the healthcheck waits for `/var/run/auth/.cookie`; on regtest it exits successfully because cookie auth is disabled and username/password auth is used instead.

## Zallet config readability and operator uid

Zallet uses a distroless image with no shell, entrypoint script, or Linux capabilities, so the base compose pins it with `user: "1000:1000"` and it runs as that uid from PID 1. Unlike Zebra, which starts with an entrypoint that can prepare filesystem state before dropping privileges, Zallet can only read its two bind-mounted host config files — `config/<network>/zallet.toml` → `/etc/zallet/zallet.toml` and `config/<network>/zallet_identity.txt` → `/etc/zallet/identity.txt` — if they are readable by uid 1000.

The same "no UID coordination required" property that the cookie sidecar provides applies here: the setup scripts make generated TOML config readable by service containers regardless of the operator's host uid, and they re-apply that permission contract on every run. `scripts/setup-network.sh` keeps generated TOMLs mode `0644`; `scripts/regtest-init.sh` restores `0644` after its `mktemp`+`mv` pwhash rewrite (which would otherwise leave `zallet.toml` mode `0600`). The age key `zallet_identity.txt` is a long-lived wallet secret, so instead of widening it to all local users it keeps group and other access closed while granting read to uid 1000 only via POSIX ACL (`setfacl -m u:1000:r`). The ACL only matters when the operator's host uid is not 1000 — when it is 1000 the owner-only key is already owned by, and readable as, uid 1000, so `setup-network.sh` skips the ACL. When the host uid is not 1000, `setfacl` (the `acl` package on Linux, with an ACL-capable filesystem such as ext4/xfs) is required: if it is unavailable or fails, the script stops with instructions rather than letting Zallet crash at startup, and the operator installs `acl` (or falls back to `chmod 644` on the identity file to allow all local users). CI runs these setup paths with restrictive host modes, derives Zallet's UID/GID from rendered Compose, verifies the ACL entries, and verifies a container running as that user can read both bind-mounted Zallet files.

## Regtest overlay constraints

### Zaino authentication

The base compose configures Zaino with cookie-based authentication (shared cookie volume with Zebra). Regtest disables cookie auth (`ZEBRA_RPC__ENABLE_COOKIE_AUTH=false`), so the regtest overlay uses `environment: !override` on Zaino to replace the full environment block, removing the cookie path and other base vars.

Regtest instead uses username/password authentication configured in `config/regtest/zaino.toml`. These credentials cannot be set via environment variables because Zaino blocks sensitive keys (containing "password") in env vars for security.

### Config file vs environment variable conflicts

Zaino's config-rs merges values from both TOML config files and environment variables. If the same field is set in both places, config-rs panics with a "duplicate field" error. The regtest Zaino config must contain only settings that are not set via environment variables. Currently it contains only `backend` and the auth credentials.

### `docker compose run` and the `--config` flag

When using `docker compose run` to execute one-off commands (for example, wallet initialization), the arguments replace the service's `command` from the compose file. The `--config /etc/zallet/zallet.toml` flag from the base service definition is not inherited. The init script must pass `--config` explicitly in every `compose run` invocation.

## `stop_grace_period`

When Docker sends `SIGTERM` to stop a container, it waits 10 seconds by default before sending `SIGKILL`. Blockchain nodes may need more time to flush state to disk. Zebra gets 30 seconds; other services get 15 seconds. This prevents potential state corruption during planned shutdowns.
