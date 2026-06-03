# Docker Compose Architecture

This document explains the architectural decisions, patterns, and modern Docker Compose features used in the Z3 stack. It serves as a reference for contributors and operators who need to understand *why* things are structured the way they are.

## Overview

```text
docker-compose.yml              Base stack (Zebra + Zaino + Zallet + optional profiles)
docker-compose.regtest.yml      Regtest overlay (structural differences only)
.env.example                    Reference for all overridable variables
.env                            User overrides (gitignored, optional)
.env.regtest                    Regtest configuration (tracked)
config/                         All service configs (mainnet defaults + regtest/ subdirectory)
scripts/                        Operational scripts (regtest-init, check-zebra-readiness, etc.)
```

The core principle: **`docker-compose.yml` is self-sufficient**. Every variable uses `${VAR:-default}` syntax, so `docker compose up` works on a fresh clone with zero configuration files. The `.env` file is purely optional; users create it only when they want to override a default.

## Defaults-in-Compose Pattern

### How it works

Every variable reference in `docker-compose.yml` includes a default value:

```yaml
image: ${ZEBRA_IMAGE:-zfnd/zebra:latest}
environment:
  ZEBRA_NETWORK__NETWORK: ${NETWORK_NAME:-Mainnet}
volumes:
  - ${Z3_ZEBRA_DATA_PATH:-zebra_data}:/home/zebra/.cache/zebra
ports:
  - "${Z3_ZEBRA_HOST_RPC_PORT:-18232}:${Z3_ZEBRA_RPC_PORT:-18232}"
```

Docker Compose resolves `${VAR:-default}` as: use `VAR` if set and non-empty, otherwise use `default`. Values come from (highest precedence first):

1. Shell environment variables (`ZEBRA_IMAGE=custom docker compose up`)
2. `.env` file in the project root
3. The `:-default` fallback in the compose file

### Why not a tracked `.env` with all defaults?

The previous approach kept a 183-line `.env` file tracked in git with all values populated. This had problems:

- **Mandatory dependency**: `docker compose up` failed without the file
- **Duplication**: Three per-network copies (mainnet/testnet/regtest) with 95% identical content
- **Drift**: Changes to defaults required updating multiple files
- **Merge conflicts**: Users who modified `.env` locally hit conflicts on every pull

With defaults in the compose file, none of these problems exist. A Testnet user creates a 1-line `.env`:

```env
NETWORK_NAME=Testnet
```

Everything else inherits from the compose defaults.

## Multi-Environment Support

### `COMPOSE_PROJECT_NAME` — Volume and Network Isolation

Docker Compose automatically prefixes all resources (volumes, networks) with the project name. This gives each environment its own isolated storage without parameterizing volume names:

| Environment | Project name | Volume on disk |
|------------|-------------|----------------|
| Mainnet | `z3` (default, from directory) | `z3_zebra_data` |
| Regtest | `z3-regtest` (from `.env.regtest`) | `z3-regtest_zebra_data` |

The same `zebra_data` volume name in the compose file creates different actual volumes depending on the project name. No naming tricks needed.

### `COMPOSE_FILE` — Automatic Overlay Loading

`.env.regtest` includes:

```env
COMPOSE_FILE=docker-compose.yml:docker-compose.regtest.yml
```

When you run `docker compose --env-file .env.regtest up`, Compose automatically loads both files and merges them. The colon-separated list is processed left to right; later files override earlier ones.

This means the regtest overlay only needs to contain *structural differences* from the base (different healthchecks, additional services, authentication changes). Everything else is inherited.

### Compose File Merge Rules

When the regtest overlay defines the same service as the base, attributes merge as follows:

| Attribute type | Merge behavior |
|----------------|---------------|
| Scalars (`image`, `command`, `container_name`) | Override replaces |
| `environment` | Merge by key name; override wins on conflict |
| `volumes` (service-level) | Merge by mount target path; same target = override wins |
| `ports` | Append |
| `healthcheck` | Override replaces entirely |
| `build.args` | Merge by key name; override wins on conflict |

Example: the base mounts `./config/zaino.toml` at `/etc/zaino/zindexer.toml`. The regtest overlay mounts `./config/regtest/zaino.toml` at the same target path. Because the target matches, the overlay's mount replaces the base's; no duplication, no conflict.

### `!override` YAML Tag — Replacing Attributes in Overlays

Standard YAML merge can add and overwrite keys but cannot *remove* them. Docker Compose v2.24+ added the `!override` tag to solve this:

```yaml
# In docker-compose.regtest.yml — replaces Zaino's entire environment block,
# removing the cookie auth path that the base compose sets
services:
  zaino:
    environment: !override
      RUST_LOG: info
      ZAINO_NETWORK: Regtest
      # ... only regtest-relevant vars, no cookie path
```

`!override` fully replaces the attribute instead of merging. The regtest overlay uses this on Zaino's `environment` to switch from cookie-based authentication (base compose) to username/password authentication (credentials in `config/regtest/zaino.toml`).

A related tag, `!reset`, clears an attribute to its default value (e.g., `ports: !reset []` empties the port list instead of appending).

Both tags require Docker Compose v2.24.0 or later.

## Extension Fields and YAML Anchors

### `x-common` — Shared Service Configuration

```yaml
x-common: &common
  logging:
    driver: json-file
    options:
      max-size: "50m"
      max-file: "5"
  cap_drop: [ALL]
  security_opt: [no-new-privileges:true]
```

Services reference this with `<<: *common`, which merges all keys from the anchor into the service definition. This ensures consistent log rotation and security hardening across all services without repeating the configuration.

Top-level keys starting with `x-` are *extension fields*; Docker Compose ignores them during processing but they serve as anchor sources for YAML reuse.

### Zebra's `setpriv` Entrypoint

Zebra's Docker entrypoint starts as root, runs `mkdir` and `chown` to set up mounted volume directories, then uses `setpriv` (part of `util-linux`, included in Debian trixie) to drop to a non-root user. These pre-privilege-drop operations need capabilities that `cap_drop: [ALL]` removes, so Zebra adds back only the 5 it needs:

```yaml
cap_add: [CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID]
```

Zaino and Zallet run as non-root from the start and work with `cap_drop: [ALL]` alone.

## Healthchecks

### `start_interval` — Two-Speed Healthchecks

Docker Engine 25.0+ supports `start_interval`, which checks more frequently during startup then backs off:

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://127.0.0.1:8080/ready || exit 1"]
  interval: 30s          # steady-state: every 30s
  start_interval: 5s     # during startup: every 5s
  start_period: 90s      # grace period before failures count
```

During the `start_period`, the check runs every `start_interval` (5s). After the first success or after `start_period` expires, it switches to `interval` (30s). This means a service that becomes ready in 10 seconds is detected in ~15 seconds instead of waiting up to 120 seconds.

### Zaino — Port Check Instead of Process Check

Zaino's image (`debian:bookworm-slim`) doesn't include `curl` or `netcat`. The healthcheck uses bash's built-in TCP socket capability:

```yaml
test: ["CMD-SHELL", "bash -c 'echo > /dev/tcp/127.0.0.1/8137' 2>/dev/null || exit 1"]
```

This verifies the gRPC port is actually accepting connections. The previous check (`zainod --version`) only confirmed the binary existed on disk; it would pass even if the service had crashed after startup.

### Regtest Zebra — RPC Check Instead of `/ready`

The base compose uses Zebra's `/ready` endpoint, which verifies the node is synced near the network tip. In regtest mode there are no peers and no network tip to sync to, so `/ready` would never succeed. The regtest overlay replaces this with a direct RPC call (`getblockchaininfo`) that confirms the RPC server is responding.

### Development Override

`docker-compose.override.yml.example` provides a ready-made override that switches Zebra's healthcheck from `/ready` to `/healthy`, allowing dependent services to start during sync. Copy it to `docker-compose.override.yml` (gitignored) for local development.

## Security Hardening

### `cap_drop: [ALL]`

Linux containers receive ~14 capabilities by default (including `CHOWN`, `DAC_OVERRIDE`, `NET_RAW`). Most applications don't need any of them. `cap_drop: [ALL]` removes all capabilities, reducing the attack surface if a container is compromised.

### `security_opt: [no-new-privileges:true]`

Prevents processes inside the container from gaining additional privileges through setuid binaries or capability inheritance. Even if an attacker writes a setuid binary into a writable tmpfs, it won't escalate privileges.

### Log Rotation

Without `max-size` and `max-file`, Docker's default `json-file` log driver grows logs unbounded. For a blockchain node running 24/7, this will eventually fill the disk. The `x-common` anchor configures 50MB per log file with 5 rotated files (250MB max per service).

## Image Override Variables

All service images are overridable via environment variables:

```yaml
image: ${ZEBRA_IMAGE:-zfnd/zebra:latest}
image: ${ZAINO_IMAGE:-ghcr.io/zcashfoundation/zaino:sha-83e41d7}
image: ${ZALLET_IMAGE:-electriccoinco/zallet:v0.1.0-alpha.3}
image: ${ZCASHD_IMAGE:-zodlinc/zcashd:v6.12.1}
```

This allows operators to:

- Pin to a specific version or digest for reproducibility
- Test a pre-release candidate without editing the compose file
- Use a private registry mirror in air-gapped environments
- Run CI with custom-built images via shell variables

## Environment Variable Strategy

### Explicit Mapping via `environment:`

All services declare their environment variables explicitly in the `environment:` block. This prevents unintended leakage of variables between services. Zallet does not support environment variable configuration at all, so it only receives `RUST_LOG`.

### Zebra's `env_file` Exception

Zebra is the only service that also uses `env_file: [{path: ./.env, required: false}]`. This exists because Zebra uses config-rs, which auto-reads any `ZEBRA_*` environment variable. Optional config-rs variables like `ZEBRA_METRICS__ENDPOINT_ADDR` and `ZEBRA_TRACING__OPENTELEMETRY_*` cannot be listed in the explicit `environment:` block with empty defaults, because config-rs treats empty strings as values and crashes when parsing `""` as a socket address or integer.

The `env_file` passthrough allows these optional variables to reach Zebra only when the user explicitly sets them in `.env`. When `.env` doesn't exist (the `required: false` case), Zebra receives only the explicit `environment:` variables and uses its built-in defaults for everything else.

Non-ZEBRA variables (ZAINO_*, Z3_*, etc.) that leak through `env_file` are harmless because config-rs ignores variables that don't match its configured prefix.

## Regtest Overlay Constraints

### Zaino Authentication

The base compose configures Zaino with cookie-based authentication (shared cookie volume with Zebra). Regtest disables cookie auth (`ENABLE_COOKIE_AUTH=false`), so the regtest overlay uses `environment: !override` on Zaino to replace the full environment block, removing the cookie path and all variables that are not needed in regtest.

Regtest instead uses username/password authentication configured in `config/regtest/zaino.toml`. These credentials cannot be set via environment variables because Zaino blocks sensitive keys (containing "password") in env vars for security reasons.

### Config File vs Environment Variable Conflicts

Zaino uses config-rs, which merges values from both TOML config files and environment variables. If the same field is set in both places, config-rs panics with a "duplicate field" error. The regtest zaino config (`config/regtest/zaino.toml`) must only contain settings that are NOT set via environment variables. Currently it contains only `backend` and the auth credentials.

### `docker compose run` and the `--config` Flag

When using `docker compose run` to execute one-off commands (e.g., wallet initialization), the arguments replace the service's `command` from the compose file. This means the `--config /etc/zallet/zallet.toml` flag from the base service definition is not inherited. The init script must pass `--config` explicitly in every `compose run` invocation.

## `stop_grace_period`

When Docker sends `SIGTERM` to stop a container, it waits 10 seconds by default before sending `SIGKILL`. Blockchain nodes may need more time to flush state to disk. Zebra gets 30 seconds; other services get 15 seconds. This prevents potential state corruption during planned shutdowns.
