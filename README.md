# Z3 - Unified Zcash Stack

This project orchestrates Zebra, Zaino, and Zallet to provide a modern, modular Zcash software stack, intended to replace the legacy `zcashd`.

## Prerequisites

Before you begin, ensure you have the following installed:

* **Docker Engine:** [Install Docker](https://docs.docker.com/engine/install/)
* **Docker Compose:** (Usually included with Docker Desktop, or [install separately](https://docs.docker.com/compose/install/))
* **rage:** For generating the Zallet identity file. Install from [str4d/rage releases](https://github.com/str4d/rage/releases) or build from source.
* **Git:** For cloning the repositories and submodules.

## Setup

1. **Clone the Repository and Submodules:**

    If you haven't already, clone this `z3` repository and initialize its submodules (Zebra, Zaino, Wallet/Zallet, Zcashd). The Docker Compose setup currently relies on local builds for Zaino and Zallet if you were to build the images from scratch (though pre-built images are specified in the compose file for ease of use).

    ```bash
    git clone <URL_to_z3_repository>
    cd z3
    git submodule update --init --recursive
    ```

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

5. **Understanding Service Configuration:**

    The services within the Z3 stack (Zebra, Zaino, Zallet) come with their own internal default configurations. For the Z3 Docker Compose setup, **all user-driven customization of service operational parameters (such as network settings, ports, log levels, and feature flags) is exclusively managed through environment variables.** These variables are defined in the `z3/.env` file (which you will create in the next step) and are then passed to the services by Docker Compose.

    You do not need to create or modify separate `.toml` configuration files for Zebra, Zaino, or Zallet in the `z3/config/` directory to control their runtime behavior in this setup; the environment variables are the sole interface for these kinds of adjustments.

6. **Create `.env` File for Docker Compose:**

    The `docker-compose.yml` file is configured to load environment variables from a `.env` file located in the `z3/` directory. This file is essential for customizing network settings, ports, log levels, and feature flags without modifying the `docker-compose.yml` directly.

    Create a `z3/.env` file. You can use the example content below as a starting point, adapting it to your needs. Refer to the comments within the example `z3/.env` or the `docker-compose.yml` for variable details.
    A comprehensive example `z3/.env` can be found alongside `docker-compose.yml`. Key variables include:

    ```env
    # z3/.env Example Snippet
    NETWORK_NAME=Testnet
    ENABLE_COOKIE_AUTH=true
    COOKIE_AUTH_FILE_DIR=/var/run/auth

    ZEBRA_RUST_LOG=info
    ZEBRA_RPC_PORT=18232
    ZEBRA_HOST_RPC_PORT=18232

    ZAINO_RUST_LOG=trace,hyper=info
    ZAINO_GRPC_PORT=8137
    ZAINO_JSON_RPC_ENABLE=false
    ZAINO_GRPC_TLS_ENABLE=true
    ZAINO_HOST_GRPC_PORT=8137
    ZAINO_GRPC_TLS_CERT_PATH=/var/run/zaino/tls/zaino.crt
    ZAINO_GRPC_TLS_KEY_PATH=/var/run/zaino/tls/zaino.key

    ZALLET_RUST_LOG=debug
    ZALLET_HOST_RPC_PORT=28232
    ```

## Running the Stack

Once the setup is complete, you can start all services using Docker Compose:

```bash
cd z3 # Ensure you are in the z3 directory
docker-compose up --build
```
* `--build`: This flag tells Docker Compose to build the images if they don't exist or if their Dockerfiles have changed. The current `docker-compose.yml` uses pre-built images for `zaino` and `zallet` specified by their SHA, and `zfnd/zebra:latest` for zebra, so `--build` might primarily affect local Dockerfile changes if you were to modify them or switch to local builds.
* To run in detached mode (in the background), add the `-d` flag: `docker-compose up -d --build`.

## Stopping the Stack

To stop the services and remove the containers, run:

```bash
docker-compose down
```

If you also want to remove the data volumes (blockchain data, indexer database, wallet database), use:

```bash
docker-compose down -v
```

## Configuration Details

Understanding how configuration is applied is key to customizing the Z3 stack:

* **Internal Service Defaults:** Each service (Zebra, Zaino, Zallet) has its own built-in default configuration values. These internal defaults are used unless influenced by environment variables. For this Z3 Docker Compose deployment, you do not directly interact with or provide TOML configuration files for the services in the `z3/config/` directory to alter these defaults for general operational parameters.

* **Environment Variables (`z3/.env`):** This is the **exclusive method for customizing the operational parameters of the Zebra, Zaino, and Zallet services within the Z3 stack.** Variables defined in the `z3/.env` file are passed into their respective containers by Docker Compose. The services are designed to read these environment variables at startup to configure their behavior (e.g., log levels, network ports, feature enablement). This approach provides a centralized and clear way to manage your deployment settings.

* **Explicitly Mounted Files & Docker Configs:** Note that specific files *are* sourced from your `z3/config/` directory for distinct purposes, such as `zallet_identity.txt` (volume mounted for Zallet) and the TLS certificates in `z3/config/tls/` (used via Docker `configs` for Zaino). These are for providing essential data or credentials, separate from the environment variable-based parameter tuning.

* **Docker Compose Overrides (`docker-compose.yml`):** The `environment` section within each service definition in `docker-compose.yml` is used for several purposes:
  * **Passing `.env` Variables:** It explicitly lists which variables from `.env` (or your shell environment) are passed into the container (e.g., `RUST_LOG=${ZALLET_RUST_LOG}`).
  * **Service Discovery & Internal Settings:** It sets variables crucial for inter-service communication (e.g., `ZAINO_VALIDATOR_LISTEN_ADDRESS=zebra:${ZEBRA_RPC_PORT}`) or paths internal to the container (e.g., `ZAINO_VALIDATOR_COOKIE_PATH=${COOKIE_AUTH_FILE_DIR}/.cookie`).
  * **Derived or Conditional Values:** Some environment variables might be constructed from others (e.g., combining `COOKIE_AUTH_FILE_DIR` with a filename) or set based on conditions (e.g., `ZAINO_VALIDATOR_COOKIE_AUTH_ENABLE=${ENABLE_COOKIE_AUTH}`).
    These `docker-compose.yml` environment settings generally take precedence if there's an overlap, as they are the final values passed when the container starts.

* **Entrypoint Scripts:** Each service's Docker image has an entrypoint script (`entrypoint.sh`). These scripts often perform final configuration steps, such as generating configuration files from templates based on environment variables, or applying conditional logic before starting the main application process.

## Interacting with Services

Once the stack is running, services can be accessed via the ports exposed in `docker-compose.yml`:

* **Zebra RPC:** `http://localhost:${ZEBRA_HOST_RPC_PORT:-18232}` (default: Testnet `http://localhost:18232`)
* **Zaino gRPC:** `localhost:${ZAINO_HOST_GRPC_PORT:-8137}` (default: `localhost:8137`)
* **Zaino JSON-RPC:** `http://localhost:${ZAINO_HOST_JSONRPC_PORT:-8237}` (default: `http://localhost:8237`, if enabled)
* **Zallet RPC:** `http://localhost:${ZALLET_HOST_RPC_PORT:-28232}` (default: `http://localhost:28232`)

Refer to the individual component documentation for RPC API details.