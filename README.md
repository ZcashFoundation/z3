# Z3 - Unified Zcash Stack

This project orchestrates Zebra, Zaino, and Zallet to provide a modern, modular Zcash software stack, intended to replace the legacy `zcashd`.

## Quick Start (TLDR)

For experienced users who know Docker and blockchain nodes:

```bash
# 1. Clone and setup
git clone https://github.com/ZcashFoundation/z3 && cd z3
git submodule update --init --recursive
openssl req -x509 -newkey rsa:4096 -keyout config/tls/zaino.key -out config/tls/zaino.crt -sha256 -days 365 -nodes -subj "/CN=localhost"
rage-keygen -o config/zallet_identity.txt

# 2. Review config/zallet.toml (update network: "main" or "test")
# 3. Review .env file (already configured with defaults)

# 4. Start Zebra and wait for sync (24-72h for mainnet, 2-12h for testnet)
docker compose up -d zebra
# Wait until: curl http://localhost:8080/ready returns "ok"

# 5. Start full stack
docker compose up -d
```

**First time?** Read the full [Setup](#setup) and [Running the Stack](#running-the-stack) sections below.

## ⚠️ Important: Docker Images Notice

**This repository builds and hosts Docker images for testing purposes only.**

- **Images use unstable development branches**:
  - Zebra: `main` branch (latest development)
  - Zaino: `dev` branch (unstable features)
  - Zallet: `main` branch (under active development)

- **Purpose**: Enable rapid testing and iteration of the Z3 stack
- **Not suitable for production use**: These images may contain bugs, breaking changes, or experimental features

**For production deployments:**
- Use official release images from respective projects:
  - Zebra: [zfnd/zebra](https://hub.docker.com/r/zfnd/zebra) (stable releases)
  - Zaino: Official releases when available
  - Zallet: Official releases when available
- Or build from stable release tags yourself

If you're testing or developing, the pre-built images from this repository provide a convenient way to quickly spin up the full Z3 stack.

## Prerequisites

Before you begin, ensure you have the following installed:

* **Docker Engine:** [Install Docker](https://docs.docker.com/engine/install/)
* **Docker Compose:** (Usually included with Docker Desktop, or [install separately](https://docs.docker.com/compose/install/))
* **rage:** For generating the Zallet identity file. Install from [str4d/rage releases](https://github.com/str4d/rage/releases) or build from source.
* **Git:** For cloning the repositories and submodules.

## Setup

1. **Clone the Repository and Submodules:**

    Clone the `z3` repository and initialize its submodules (Zebra, Zaino, Zallet):

    ```bash
    git clone https://github.com/ZcashFoundation/z3
    cd z3
    git submodule update --init --recursive
    ```

    The Docker Compose setup builds all images locally from submodules by default.

2. **Required Files:**

    You'll need to generate these files in the `config/` directory:
    - `config/tls/zaino.crt` and `config/tls/zaino.key` - Zaino TLS certificates
    - `config/zallet_identity.txt` - Zallet encryption key
    - `config/zallet.toml` - Zallet configuration (provided, review and customize)

3. **Generate Zaino TLS Certificates:**

    ```bash
    openssl req -x509 -newkey rsa:4096 -keyout config/tls/zaino.key -out config/tls/zaino.crt -sha256 -days 365 -nodes -subj "/CN=localhost" -addext "subjectAltName = DNS:localhost,IP:127.0.0.1"
    ```

    This creates a self-signed certificate valid for 365 days. For production, use certificates from a trusted CA.

4. **Generate Zallet Identity File:**

    ```bash
    rage-keygen -o config/zallet_identity.txt
    ```

    **Securely back up this file and the public key** (printed to terminal).

5. **Review Zallet Configuration:**

    Review `config/zallet.toml` and update the network setting:
    - For mainnet: `network = "main"` in `[consensus]` section
    - For testnet: `network = "test"` in `[consensus]` section

    See [Configuration Guide](#configuration-guide) for details on Zallet's architecture and config requirements.

6. **Review Environment Variables:**

    A comprehensive `.env` file is provided with sensible defaults. Review and customize as needed:
    - `NETWORK_NAME` - Set to `Mainnet` or `Testnet`
    - Log levels for each service (defaults to `info` with warning filters)
    - Port mappings (defaults work for most setups)

    See [Configuration Guide](#configuration-guide) for the complete variable hierarchy and customization options.

## Running the Stack

The Z3 stack uses a **two-phase deployment** approach following blockchain industry best practices:

### Quick Start (Synced State)

If you have an already-synced Zebra state (cached or imported):

```bash
cd z3
docker compose up -d
```

All services start quickly (within minutes) and are ready to use.

### Fresh Sync (First Time Setup)

**⚠️ IMPORTANT**: Initial blockchain sync can take **24+ hours for mainnet** or **several hours for testnet**. Zebra must sync before dependent services (Zaino, Zallet) can function.

#### Phase 1: Sync Zebra (One-time)

```bash
cd z3

# Start only Zebra
docker compose up -d zebra

# Monitor sync progress (choose one)
docker compose logs -f zebra                    # View logs
watch curl -s http://localhost:8080/ready       # Poll readiness endpoint

# Or use this script to wait until Zebra is ready:
while true; do
  response=$(curl -s http://127.0.0.1:8080/ready)
  if [ "$response" = "ok" ]; then
    echo "Zebra is ready!"
    break
  fi
  echo "Not ready yet: $response"
  sleep 5
done

# Zebra is ready when /ready returns "ok"
```

**How long will this take?**
- **Mainnet**: 24-72 hours (depending on hardware and network)
- **Testnet**: 2-12 hours (currently ~3.1M blocks)
- **Cached/Resumed**: Minutes (if using existing Zebra state)

#### Phase 2: Start Full Stack

Once Zebra shows `/ready` returning `ok`:

```bash
# Start all remaining services
docker compose up -d

# Verify all services are healthy
docker compose ps
```

Services start immediately since Zebra is already synced.

### Development Mode (Optional)

For quick iteration during development without waiting for sync:

```bash
# Copy development override
cp docker-compose.override.yml.example docker-compose.override.yml

# Start all services (uses /healthy instead of /ready)
docker compose up -d
```

**⚠️ WARNING**: In development mode, Zaino and Zallet may experience delays while Zebra syncs. Only use for testing, NOT production.

## Stopping the Stack

To stop the services and remove the containers:

```bash
docker compose down
```

To also remove the data volumes (⚠️ **deletes all blockchain data, indexer database, wallet database**):

```bash
docker compose down -v
```

## Data Storage & Volumes

The Z3 stack stores blockchain data, indexer state, and wallet data in Docker volumes. You can choose between Docker-managed volumes (default) or local directories.

### Default: Docker Named Volumes (Recommended)

By default, the stack uses Docker named volumes which are managed by Docker:

- `zebra_data`: Zebra blockchain state (~300GB+ for mainnet, ~30GB for testnet)
- `zaino_data`: Zaino indexer database
- `zallet_data`: Zallet wallet data
- `shared_cookie_volume`: RPC authentication cookies

**Advantages:**
- No permission issues
- Automatic management by Docker
- Better performance on macOS/Windows

### Advanced: Local Directories

For advanced use cases (backups, external SSDs, shared storage), you can bind local directories instead of using Docker-managed volumes.

**Important:** Choose directory locations appropriate for your operating system and requirements:
- Linux: `/mnt/data/z3`, `/var/lib/z3`, or user home directories
- macOS: `/Volumes/ExternalDrive/z3`, `~/Library/Application Support/z3`, or user Documents
- Windows (WSL): `/mnt/c/Z3Data` or native Windows paths if using Docker Desktop

#### Setup Steps

1. **Create your directories** in your chosen location:
   ```bash
   mkdir -p /your/chosen/path/zebra-state
   mkdir -p /your/chosen/path/zaino-data
   mkdir -p /your/chosen/path/zallet-data
   ```

2. **Fix permissions** using the provided utility:
   ```bash
   ./fix-permissions.sh zebra /your/chosen/path/zebra-state
   ./fix-permissions.sh zaino /your/chosen/path/zaino-data
   ./fix-permissions.sh zallet /your/chosen/path/zallet-data
   ```

   Note: Keep the cookie directory as a Docker volume (recommended) to avoid cross-user permission issues.

3. **Update `.env` file** with your paths:
   ```bash
   Z3_ZEBRA_DATA_PATH=/your/chosen/path/zebra-state
   Z3_ZAINO_DATA_PATH=/your/chosen/path/zaino-data
   Z3_ZALLET_DATA_PATH=/your/chosen/path/zallet-data
   # Z3_COOKIE_PATH=shared_cookie_volume  # Keep as Docker volume
   ```

4. **Restart the stack**:
   ```bash
   docker compose down
   docker compose up -d
   ```

#### Security Requirements

Each service runs as a specific non-root user with distinct UIDs/GIDs:

- **Zebra**: UID=10001, GID=10001, permissions 700
- **Zaino**: UID=1000, GID=1000, permissions 700
- **Zallet**: UID=65532, GID=65532, permissions 700

**Critical:** Local directories must have correct ownership and secure permissions:
- Use `fix-permissions.sh` to set ownership automatically
- Permissions must be 700 (owner only) or 750 (owner + group read)
- **Never use 755 or 777** - these expose your blockchain data and wallet to other users

## Configuration Guide

This section explains how the Z3 stack is configured and how to customize it for your needs.

### Configuration Overview

The Z3 stack uses a layered configuration approach:

1. **Service Defaults** - Built-in defaults for each service
2. **Environment Variables** (`.env`) - Runtime configuration and customization
3. **Configuration Files** - Required for specific services (Zallet, Zaino TLS)
4. **Docker Compose Remapping** - Transforms variables for service-specific formats

### Variable Hierarchy

The Z3 stack uses a **three-tier variable naming system** to avoid collisions:

**1. Z3_* Variables (Infrastructure)**
- Purpose: Docker-level configuration (volume paths, port mappings, service discovery)
- Scope: Used only in `docker-compose.yml`, never passed directly to containers
- Examples: `Z3_ZEBRA_DATA_PATH`, `Z3_ZEBRA_RPC_PORT`, `Z3_ZEBRA_RUST_LOG`
- Why: Prevents collision with service configuration variables

**2. Shared Variables (Common Configuration)**
- Purpose: Settings used by multiple services
- Scope: Remapped in `docker-compose.yml` to service-specific names
- Examples:
  - `NETWORK_NAME` → `ZEBRA_NETWORK__NETWORK`, `ZAINO_NETWORK`, `ZALLET_NETWORK`
  - `ENABLE_COOKIE_AUTH` → `ZEBRA_RPC__ENABLE_COOKIE_AUTH`, `ZAINO_VALIDATOR_COOKIE_AUTH`
  - `COOKIE_AUTH_FILE_DIR` → Mapped to cookie paths for each service

**3. Service Configuration Variables (Application Config)**
- Purpose: Service-specific configuration passed to applications
- Scope: Passed via `env_file` in `docker-compose.yml`
- Formats:
  - **Zebra**: `ZEBRA_*` (config-rs format: `ZEBRA_SECTION__KEY` with `__` separator)
  - **Zaino**: `ZAINO_*`
  - **Zallet**: `ZALLET_*`

### Configuration Approaches by Service

**Zebra:**
- **Method**: Pure environment variables
- **Format**: `ZEBRA_SECTION__KEY` (e.g., `ZEBRA_RPC__LISTEN_ADDR`)
- **Files**: None required (uses environment variables only)

**Zaino:**
- **Method**: Pure environment variables
- **Format**: `ZAINO_*` (e.g., `ZAINO_GRPC_PORT`)
- **Files**: TLS certificates (`config/tls/zaino.crt`, `config/tls/zaino.key`)

**Zallet:**
- **Method**: Hybrid (TOML file + environment variables)
- **Format**: `ZALLET_*` for runtime parameters (e.g., `ZALLET_RUST_LOG`)
- **Files**:
  - `config/zallet.toml` - Core configuration (required)
  - `config/zallet_identity.txt` - Encryption key (required)

### Zallet's Architecture

Zallet differs from Zebra and Zaino in key ways:

**Embedded Indexer:**
- Zallet includes an **embedded indexer** that connects directly to **Zebra's JSON-RPC** endpoint
- It does NOT use Zaino's indexer service
- It fetches blockchain data directly from Zebra

**Service Connectivity:**
```
Zebra (JSON-RPC :18232)
  ├─→ Zaino (indexes blocks via JSON-RPC)
  └─→ Zallet (embedded indexer via JSON-RPC)
```

**Critical Configuration Requirements:**
1. `config/zallet.toml` must exist with all required sections (even if empty)
2. `validator_address` must point to `zebra:18232` (Zebra's JSON-RPC), **NOT** `zaino:8137`
3. All TOML sections must be present: `[builder]`, `[consensus]`, `[database]`, `[external]`, `[features]`, `[indexer]`, `[keystore]`, `[note_management]`, `[rpc]`
4. Cookie authentication must be configured in both TOML and mounted as a volume

### Common Customizations

**Change Network (Mainnet/Testnet):**
```bash
# In .env:
NETWORK_NAME=Mainnet  # or Testnet

# In config/zallet.toml:
[consensus]
network = "main"  # or "test"
```

**Adjust Log Levels:**
```bash
# In .env:
Z3_ZEBRA_RUST_LOG=info
ZAINO_RUST_LOG=info,reqwest=warn,hyper_util=warn
ZALLET_RUST_LOG=info,hyper_util=warn,reqwest=warn

# For debugging, use:
ZAINO_RUST_LOG=debug
```

**Change Ports:**
```bash
# In .env:
Z3_ZEBRA_HOST_RPC_PORT=18232
ZAINO_HOST_GRPC_PORT=8137
ZALLET_HOST_RPC_PORT=28232
```

**Environment Variable Precedence:**

Docker Compose applies variables in this order (later overrides earlier):
1. Dockerfile defaults
2. `.env` file substitution (e.g., `${VARIABLE}`)
3. `env_file` section
4. `environment` section
5. Shell environment variables (if exported)

**Important**: If you export a variable in your shell, it will override the `.env` file. Use `unset VARIABLE` to remove shell variables.

## Health and Readiness Checks

Zebra provides two HTTP endpoints for monitoring service health:

### `/healthy` - Liveness Check
- **Returns 200**: Zebra is running and has minimum connected peers (configurable, default: 1)
- **Returns 503**: Not enough peer connections
- **Use for**: Docker healthchecks, liveness monitoring, restart decisions
- **Works during**: Initial sync, normal operation
- **Endpoint**: `http://localhost:${Z3_ZEBRA_HOST_HEALTH_PORT:-8080}/healthy`

### `/ready` - Readiness Check
- **Returns 200**: Zebra is synced near the network tip (within configured blocks, default: 2)
- **Returns 503**: Still syncing or lagging behind network tip
- **Use for**: Production traffic routing, manual verification before use
- **Fails during**: Fresh sync (can take 24+ hours for mainnet)
- **Endpoint**: `http://localhost:${Z3_ZEBRA_HOST_HEALTH_PORT:-8080}/ready`

### Service Dependency Strategy

The Z3 stack uses **readiness-based dependencies** to prevent service hangs:

```
Zebra (/ready - synced near tip)
  → Zaino (gRPC responding)
    → Zallet (RPC responding)
```

**Why this approach:**
- **Zaino requires Zebra to be near the network tip** - if Zebra is still syncing, Zaino will hang internally waiting
- **Two-phase deployment** separates initial sync from normal operation
- **Docker Compose healthcheck** verifies Zebra is synced before starting dependent services

**What each healthcheck tests:**
- `zebra`: `/ready` - Synced near network tip (within 2 blocks, configurable)
- `zaino`: gRPC server responding - Ready to index blocks
- `zallet`: RPC server responding - Ready for wallet operations

**Deployment modes:**

| Mode | When to use | Zebra healthcheck | Behavior |
|------|-------------|-------------------|----------|
| **Production** (default) | Mainnet, production testnet | `/ready` | Two-phase: sync Zebra first, then start stack |
| **Development** (override) | Local dev, quick testing | `/healthy` | Start all services immediately (may have delays) |

### Monitoring Sync Progress

During Phase 1 (Zebra sync), monitor progress:

```bash
# Check readiness (returns "ok" when synced near tip)
curl http://localhost:8080/ready

# Monitor sync progress via logs
docker compose logs -f zebra

# Check current status
docker compose ps zebra
```

**What to expect:**
- Zebra shows `healthy (starting)` while syncing (during 90-second grace period)
- Once synced, `/ready` returns `ok` and Zebra shows `healthy`
- Zaino and Zallet remain in `waiting` state until dependencies are healthy

### Configuration Options

**Skip sync wait for development** (`.env`):
```bash
# Make /ready always return 200 on testnet (even during sync)
ZEBRA_HEALTH__ENFORCE_ON_TEST_NETWORKS=false  # Default: false

# When set to true, testnet behaves like mainnet (strict readiness check)
```

**Adjust readiness threshold** (`.env`):
```bash
# How many blocks behind network tip is acceptable (default: 2)
ZEBRA_HEALTH__READY_MAX_BLOCKS_BEHIND=2

# Minimum peer connections for /healthy (default: 1)
ZEBRA_HEALTH__MIN_CONNECTED_PEERS=1
```

## Interacting with Services

Once the stack is running, services can be accessed via their exposed ports:

* **Zebra RPC:** `http://localhost:${Z3_ZEBRA_HOST_RPC_PORT:-18232}` (default: Testnet `http://localhost:18232`)
* **Zebra Health:** `http://localhost:${Z3_ZEBRA_HOST_HEALTH_PORT:-8080}/healthy` and `/ready`
* **Zaino gRPC:** `localhost:${ZAINO_HOST_GRPC_PORT:-8137}` (default: `localhost:8137`)
* **Zaino JSON-RPC:** `http://localhost:${ZAINO_HOST_JSONRPC_PORT:-8237}` (default: `http://localhost:8237`, if enabled)
* **Zallet RPC:** `http://localhost:${ZALLET_HOST_RPC_PORT:-28232}` (default: `http://localhost:28232`)

Refer to the individual component documentation for RPC API details.