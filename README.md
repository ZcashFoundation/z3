# Z3 - Unified Zcash Stack

A modern, modular Zcash software stack combining Zebra, Zaino, and Zallet to replace the legacy `zcashd`.

## Table of Contents

- [Quick Start](#quick-start)
- [Understanding the Architecture](#understanding-the-architecture)
- [Docker Images](#docker-images)
- [Prerequisites](#prerequisites)
- [System Requirements](#system-requirements)
- [Setup](#setup)
- [Running the Stack](#running-the-stack)
- [Stopping the Stack](#stopping-the-stack)
- [Data Storage & Volumes](#data-storage--volumes)
- [Interacting with Services](#interacting-with-services)
- [Configuration Guide](#configuration-guide)
- [Health and Readiness Checks](#health-and-readiness-checks)

---

## Quick Start

> [!IMPORTANT]
> **First time running Z3?** You must sync Zebra before starting the other services. This takes **24-72 hours for mainnet** or **2-12 hours for testnet**. There is no way around this initial sync.
>
> **Already have synced Zebra data?** You can start all services immediately.

### First Time Setup (No Existing Data)

```bash
# 1. Clone and generate required files
git clone https://github.com/ZcashFoundation/z3 && cd z3
git submodule update --init --recursive
openssl req -x509 -newkey rsa:4096 -keyout config/tls/zaino.key -out config/tls/zaino.crt \
  -sha256 -days 365 -nodes -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:zaino,IP:127.0.0.1"
rage-keygen -o config/zallet_identity.txt

# 2. Build Zaino and Zallet (required - no pre-built images available)
docker compose build zaino zallet

# 3. Set up environment
#    - Copy the example for your network:
#      cp .env.example.mainnet .env       # for Mainnet
#      cp .env.example.testnet .env       # for Testnet
#    - Review .env and update as needed
#    - config/zallet.toml: set network = "main" or "test"

# 4. Start ONLY Zebra first
docker compose up -d zebra

# 5. Wait for Zebra to sync (this takes hours/days)
./check-zebra-readiness.sh
# Or manually: curl http://localhost:8080/ready (returns "ok" when synced)

# 6. Once Zebra is synced, start the remaining services
docker compose up -d
```

> [!NOTE]
> The `check-zebra-readiness.sh` script polls Zebra's readiness endpoint and notifies you when sync is complete. You can safely close your terminal during sync and check back later.

### With Existing Synced Data

If you have previously synced Zebra data (or are mounting existing blockchain state):

```bash
# Build if not already built
docker compose build zaino zallet

# All services can start immediately
docker compose up -d

# Verify all services are healthy
docker compose ps
```

> [!TIP]
> **ARM64 Users (Apple Silicon):** Set `DOCKER_PLATFORM=linux/arm64` in `.env` for native builds. This reduces build time from ~50 minutes to ~3 minutes.

---

## Understanding the Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Z3 Stack                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────┐         ┌─────────┐         ┌─────────┐          │
│   │  Zebra  │◄────────│  Zaino  │         │ Zallet  │          │
│   │  (node) │         │ (index) │         │(wallet) │          │
│   └────┬────┘         └─────────┘         └────┬────┘          │
│        │                                       │                │
│        │              ┌─────────────┐          │                │
│        └──────────────│ Embedded    │◄─────────┘                │
│                       │ Zaino libs  │                           │
│                       └─────────────┘                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

> [!NOTE]
> **Zallet embeds Zaino libraries internally.** It connects directly to Zebra's JSON-RPC, not to the standalone Zaino service. The Zaino container in this stack is for external gRPC clients (like Zingo wallet) and for testing the indexer independently.

**Service Roles:**
- **Zebra** - Full node that syncs and validates the Zcash blockchain
- **Zaino** - Standalone indexer providing gRPC interface for light wallets
- **Zallet** - Wallet service with embedded indexer that talks directly to Zebra

## Docker Images

### Image Sources

| Service | Image | Source |
|---------|-------|--------|
| **Zebra** | `zfnd/zebra:4.1.0` | [ZcashFoundation/zebra](https://github.com/ZcashFoundation/zebra) |
| **Zaino** | `ghcr.io/zcashfoundation/zaino:sha-1871eba` | [zingolabs/zaino](https://github.com/zingolabs/zaino) |
| **Zallet** | `electriccoinco/zallet:v0.1.0-alpha.3` | [zcash/wallet](https://github.com/zcash/wallet) |

### Building Local Images (Optional)

To build from local submodules instead of using pre-built images:

```bash
# Initialize submodules
git submodule update --init --recursive

# Build all services locally
docker compose build
```

> [!NOTE]
> The submodules in this repository are pinned to tested, compatible commits if you prefer to build locally.

## Prerequisites

Before you begin, ensure you have the following installed:

* **Docker Engine:** [Install Docker](https://docs.docker.com/engine/install/)
* **Docker Compose:** (Usually included with Docker Desktop, or [install separately](https://docs.docker.com/compose/install/))
* **Docker Permissions (Linux):** You may need to run Docker commands with `sudo`, or add your user to the `docker` group. See [Docker's post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user) for details. Note that the `docker` group grants root-level privileges.
* **rage:** For generating the Zallet identity file. Install from [str4d/rage releases](https://github.com/str4d/rage/releases) or build from source.
* **Git:** For cloning the repositories and submodules.

## System Requirements

Running the full Z3 stack (Zebra + Zaino + Zallet) requires substantial hardware resources due to blockchain synchronization and indexing.

### Minimum Specifications

- **CPU:** 2 cores (4+ cores strongly recommended)
- **RAM:** 4 GB for Zebra; 8+ GB recommended for full stack
- **Disk Space:**
  - Mainnet: 300 GB (blockchain state)
  - Testnet: 30 GB (blockchain state)
  - Additional space for Zaino indexer database (requirements under determination)
  - SSD strongly recommended for sync performance
- **Network:** Reliable internet connection
  - Initial sync download: ~300 GB for mainnet
  - Ongoing bandwidth: 10 MB - 10 GB per day

### Recommended Specifications

- **CPU:** 4+ cores
- **RAM:** 16+ GB
- **Disk Space:** 500+ GB with room for blockchain growth
- **Network:** 100+ Mbps connection with ~300 GB/month bandwidth

### Sync Time Expectations

- **Mainnet:** 24-72 hours on recommended hardware
- **Testnet:** 2-12 hours (currently ~3.1M blocks)
- **Cached/Resumed:** Minutes (if using existing Zebra state)

Sync time varies based on CPU speed, disk I/O (SSD vs HDD), and network bandwidth.

**Note:** These specifications are based on [Zebra's official requirements](https://zebra.zfnd.org/user/requirements.html). Zaino indexer adds additional resource overhead; specific requirements are under determination. Running all three services together requires resources beyond Zebra alone.

## Setup

1. **Clone the Repository:**

    Clone the `z3` repository:

    ```bash
    git clone https://github.com/ZcashFoundation/z3
    cd z3
    ```

    **Using Pre-Built Images (Recommended):** Submodules are not required. Skip to step 2.

    **Building Locally (Optional):** Initialize submodules to build from source:

    ```bash
    git submodule update --init --recursive
    ```

2. **Platform Configuration (Apple Silicon / ARM64):**

    **ARM64 users**: Enable native builds for dramatically faster performance.

    Z3 defaults to AMD64 (x86_64) for development consistency. On ARM64 systems (Apple Silicon M1/M2/M3 or ARM64 Linux), this uses emulation which is **very slow**:
    - AMD64 emulation: ~50 minutes to build Zebra
    - Native ARM64: ~2-3 minutes to build Zebra

    **To enable native ARM64 builds:**

    Edit `.env` and uncomment the `DOCKER_PLATFORM` line:

    ```bash
    # In .env file, change this:
    # DOCKER_PLATFORM=linux/arm64

    # To this:
    DOCKER_PLATFORM=linux/arm64
    ```

    Or set it directly in your shell:

    ```bash
    echo "DOCKER_PLATFORM=linux/arm64" >> .env
    ```

    **Intel/AMD users**: No action needed. Default AMD64 settings work optimally.

3. **Required Files:**

    You'll need to generate these files in the `config/` directory:
    - `config/tls/zaino.crt` and `config/tls/zaino.key` - Zaino TLS certificates
    - `config/zallet_identity.txt` - Zallet encryption key
    - `config/zallet.toml` - Zallet configuration (provided, review and customize)

4. **Generate Zaino TLS Certificates:**

    ```bash
    openssl req -x509 -newkey rsa:4096 -keyout config/tls/zaino.key -out config/tls/zaino.crt -sha256 -days 365 -nodes -subj "/CN=localhost" -addext "subjectAltName = DNS:localhost,IP:127.0.0.1"
    ```

    This creates a self-signed certificate valid for 365 days. For production, use certificates from a trusted CA.

5. **Generate Zallet Identity File:**

    ```bash
    rage-keygen -o config/zallet_identity.txt
    ```

    **Securely back up this file and the public key** (printed to terminal).

6. **Review Zallet Configuration:**

    Review `config/zallet.toml` and update the network setting:
    - For mainnet: `network = "main"` in `[consensus]` section
    - For testnet: `network = "test"` in `[consensus]` section

    See [Configuration Guide](#configuration-guide) for details on Zallet's architecture and config requirements.

7. **Set up Environment Variables:**

    Copy the example file for your target network:

    ```bash
    cp .env.example.mainnet .env    # Mainnet
    cp .env.example.testnet .env    # Testnet
    ```

    Review `.env` and customize as needed:
    - `NETWORK_NAME` - Set to `Mainnet` or `Testnet`
    - Log levels for each service (defaults to `info` with warning filters)
    - Port mappings (defaults work for most setups)

    See [Configuration Guide](#configuration-guide) for the complete variable hierarchy and customization options.

## Running the Stack

> [!WARNING]
> **Why can't I just run `docker compose up`?**
>
> Docker Compose healthchecks have timeout limits that cannot accommodate blockchain sync times (hours to days). If you run `docker compose up` on a fresh install, Zaino and Zallet will repeatedly fail waiting for Zebra to sync.
>
> **Solution:** Start Zebra alone first, wait for sync, then start everything else.

### First Time (Fresh Sync Required)

```bash
# Step 1: Start only Zebra
docker compose up -d zebra

# Step 2: Monitor sync progress (choose one method)
./check-zebra-readiness.sh              # Recommended: script waits and notifies
docker compose logs -f zebra             # Watch logs
curl http://localhost:8080/ready         # Manual check (returns "ok" when synced)

# Step 3: Once synced, start all services
docker compose up -d
```

> [!NOTE]
> **Sync times:**
> - Mainnet: 24-72 hours (depends on hardware/network)
> - Testnet: 2-12 hours
>
> You can close your terminal during sync. Zebra runs in the background.

### Returning User (Existing Data)

If Zebra has previously synced (data persists in Docker volumes):

```bash
docker compose up -d
docker compose ps  # Verify all healthy
```

### Development Mode

For local development when you need services running during sync:

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
docker compose up -d
```

> [!CAUTION]
> Development mode uses `/healthy` instead of `/ready`. Services will start but may error until Zebra catches up. Not for production use.

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

**Embedded Zaino Indexer:**
- Zallet embeds **Zaino's indexer libraries** (`zaino-fetch`, `zaino-state`, `zaino-proto`) as dependencies
- This embedded indexer connects directly to **Zebra's JSON-RPC** endpoint to fetch blockchain data
- Zallet does **NOT** connect to the standalone Zaino gRPC/JSON-RPC service (which is for other light clients)

**Service Connectivity:**
```
Zebra (JSON-RPC :18232)
  ├─→ Zaino Service (standalone indexer for gRPC clients like Zingo)
  └─→ Zallet (uses embedded Zaino indexer libraries)
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