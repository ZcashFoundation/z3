# Z3 - Unified Zcash Stack

This project orchestrates Zebra, Zaino, and Zallet to provide a modern, modular Zcash software stack, intended to replace the legacy `zcashd`.

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

2. **Configuration Directories:**

    After cloning the repository, you will find the following configuration directories, which are tracked by Git and will be populated with essential files in subsequent steps:

    *   `config/`: This directory is intended to hold user-generated files that are essential for the Z3 stack's operation. Specifically, you will place:
        *   `zallet_identity.txt` (Zallet age identity file for encryption - _you will generate this in a later step_).
    *   `config/tls/`: This subdirectory is for TLS certificate files that you will generate:
        *   `zaino.crt` (Zaino's TLS certificate - _you will generate this_)
        *   `zaino.key` (Zaino's TLS private key - _you will generate this_)

3. **Generate Zaino TLS Certificates:**

    Zaino requires a TLS certificate and private key for its gRPC interface. These files should be placed in the `config/tls/` directory.

    * `config/tls/zaino.crt`: The TLS certificate for Zaino.
    * `config/tls/zaino.key`: The private key for Zaino's TLS certificate.

    You will need to generate these files using your preferred method (e.g., OpenSSL). For example, to generate a self-signed certificate:

    ```bash
    openssl req -x509 -newkey rsa:4096 -keyout config/tls/zaino.key -out config/tls/zaino.crt -sha256 -days 365 -nodes -subj "/CN=localhost" -addext "subjectAltName = DNS:localhost,IP:127.0.0.1"
    ```

    **Note:** For production or more secure setups, use certificates issued by a trusted Certificate Authority (CA). The example above creates a self-signed certificate valid for 365 days and includes `localhost` and `127.0.0.1` as Subject Alternative Names (SANs), which is important for client validation.

4. **Generate Zallet Identity File:**

    Zallet requires an `age` identity file for wallet encryption. Generate this file using `rage-keygen`:

    ```bash
    rage-keygen -o config/zallet_identity.txt
    ```

    This will create `config/zallet_identity.txt`. **Securely back up this file and its corresponding public key.** The public key will be printed to your terminal during generation.

5. **Understanding the Variable Hierarchy:**

    The Z3 stack uses a **three-tier variable naming system** to avoid collisions and organize configuration clearly:

    **1. Z3_* Variables (Infrastructure)**
    - Used **only** in `docker-compose.yml` for Docker-level configuration (volume paths, port mappings, service discovery)
    - **Never** directly passed to containers (unless explicitly remapped)
    - Examples: `Z3_ZEBRA_DATA_PATH`, `Z3_ZEBRA_RPC_PORT`, `Z3_ZEBRA_RUST_LOG`
    - Why? Prevents collision with service configuration variables

    **2. Shared Variables (Common Configuration)**
    - Used by multiple services, remapped in `docker-compose.yml`
    - Examples: `NETWORK_NAME`, `ENABLE_COOKIE_AUTH`, `COOKIE_AUTH_FILE_DIR`
    - These are transformed to service-specific variable names (e.g., `NETWORK_NAME` → `ZAINO_NETWORK`)

    **3. Service Configuration Variables (Application Config)**
    - Passed directly to applications via `env_file` in `docker-compose.yml`
    - **Zebra**: `ZEBRA_*` (config-rs format: `ZEBRA_SECTION__KEY` uses `__` between section and key)
    - **Zaino**: `ZAINO_*`
    - **Zallet**: `ZALLET_*`

    You do not need to create or modify separate `.toml` configuration files; the environment variables are the sole interface for customization. See the `.env` file header for detailed examples of variable flow.

6. **Create `.env` File for Docker Compose:**

    The `docker-compose.yml` file is configured to load environment variables from a `.env` file located in the `z3/` directory. This file is essential for customizing network settings, ports, log levels, and feature flags without modifying the `docker-compose.yml` directly.

    Create a `z3/.env` file. You can use the example content below as a starting point, adapting it to your needs. Refer to the comments within the example `z3/.env` or the `docker-compose.yml` for variable details.
    A comprehensive example `z3/.env` can be found alongside `docker-compose.yml`. Key variables include:

    ```env
    # z3/.env Example Snippet

    # Shared configuration (mapped per service in docker-compose.yml)
    NETWORK_NAME=Testnet
    ENABLE_COOKIE_AUTH=true
    COOKIE_AUTH_FILE_DIR=/var/run/auth

    # Zebra infrastructure and service config
    Z3_ZEBRA_RUST_LOG=info
    Z3_ZEBRA_RPC_PORT=18232
    ZEBRA_RPC__LISTEN_ADDR=0.0.0.0:18232

    # Zaino service config
    ZAINO_RUST_LOG=trace,hyper=info
    ZAINO_GRPC_PORT=8137
    ZAINO_GRPC_TLS_ENABLE=true

    # Zallet service config
    ZALLET_RUST_LOG=debug
    ZALLET_HOST_RPC_PORT=28232
    ```

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

## Configuration Details

Understanding how configuration is applied is key to customizing the Z3 stack. For the variable hierarchy (Z3_*, shared, and service-specific variables), see **Setup section 5**.

### Configuration Layers

* **Internal Service Defaults:** Each service (Zebra, Zaino, Zallet) has built-in default configuration values used unless overridden by environment variables. You do not need to create TOML configuration files for general operational parameters.

* **Environment Variables (`z3/.env`):** This is the **exclusive method for customizing operational parameters.** Variables are passed to containers via `env_file` (direct pass-through) or `environment` (remapping/construction) in `docker-compose.yml`.

* **Explicitly Mounted Files & Docker Configs:** Note that specific files *are* sourced from your `z3/config/` directory for distinct purposes, such as `zallet_identity.txt` (volume mounted for Zallet) and the TLS certificates in `z3/config/tls/` (used via Docker `configs` for Zaino). These are for providing essential data or credentials, separate from the environment variable-based parameter tuning.

* **Docker Compose Remapping (`docker-compose.yml`):** The `environment` section within each service definition is used to:
  * **Remap infrastructure variables:** Maps `Z3_*` variables to service-specific names (e.g., `Z3_ZEBRA_RUST_LOG` → `RUST_LOG`)
  * **Remap shared variables:** Maps common config to service-specific names (e.g., `NETWORK_NAME` → `ZAINO_NETWORK`, `ENABLE_COOKIE_AUTH` → `ZEBRA_RPC__ENABLE_COOKIE_AUTH`)
  * **Service Discovery:** Constructs connection strings using infrastructure variables (e.g., `ZAINO_VALIDATOR_LISTEN_ADDRESS=zebra:${Z3_ZEBRA_RPC_PORT}`)

  Variables in the `environment` section override those from `env_file` if there's a conflict.

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