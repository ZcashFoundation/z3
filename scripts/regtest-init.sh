#!/usr/bin/env bash
# regtest-init.sh: initialize the regtest wallet for the first time.
#
# Delegates first-run file setup to scripts/setup-network.sh, then performs
# the regtest-specific steps: write the Zallet RPC password hash, mine the
# activation blocks, and generate the wallet mnemonic.
#
# Run this once before starting the regtest stack. Safe to re-run.
#
# Requirements:
#   - Docker with Docker Compose v2.24.4+
#   - rage-keygen, openssl (used by setup-network.sh)
#   - No running z3-regtest-* containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.regtest"
COMPOSE="docker compose --env-file $ENV_FILE"

# Source the env file so port + project vars are available in this shell.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

PROJECT="${COMPOSE_PROJECT_NAME:-z3-regtest}"
ZEBRA_HOST_RPC="${Z3_ZEBRA_HOST_RPC_PORT:-29232}"
ZAINO_HOST_GRPC="${Z3_ZAINO_HOST_GRPC_PORT:-28137}"
CONFIG_DIR="${Z3_CONFIG_DIR:-./config/regtest}"

log() {
    printf '%s\n' "$*"
}

require_compose_v2() {
    # This stack relies on the colon-separated COMPOSE_FILE merge and the
    # !override tag, both Docker Compose v2.24.4+ features. The legacy v1
    # `docker-compose` binary cannot load them, so we require the v2 plugin
    # and do not fall back to v1.
    local ver need="2.24.4"
    # A single `docker compose version --short` both proves the v2 plugin
    # exists (non-zero exit otherwise) and yields the version to gate on.
    if ! ver="$(docker compose version --short 2>/dev/null)"; then
        log "Docker Compose v2 is required (the 'docker compose' plugin)."
        log "The legacy 'docker-compose' v1 binary cannot load this stack's"
        log "COMPOSE_FILE merge and !override tag. Install Compose v2.24.4+:"
        log "  https://docs.docker.com/compose/install/"
        exit 1
    fi
    ver="${ver#v}"
    if [ -n "$ver" ] && [ "$(printf '%s\n%s\n' "$need" "$ver" | sort -V | head -n1)" != "$need" ]; then
        log "Docker Compose $ver found, but >= $need is required (the regtest"
        log "overlay uses the !override tag). Upgrade Docker Compose."
        exit 1
    fi
}

ensure_openssl() {
    if command -v openssl > /dev/null 2>&1; then
        return
    fi

    log "openssl is required to generate the zallet RPC password hash."
    log "Install OpenSSL, then re-run this script."
    exit 1
}

update_zallet_rpc_pwhash() {
    local config_path="$REPO_ROOT/${CONFIG_DIR#./}/zallet.toml"
    # Keep Zallet's RPC password hash aligned with the rpc-router credential.
    local rpc_password="${Z3_REGTEST_RPC_ROUTER_PASSWORD:-zebra}"
    local placeholder="__GENERATED_BY_INIT_SH__"
    local salt
    local hash
    local pwhash
    local tmp

    if [ ! -f "$config_path" ]; then
        log "Missing zallet config: $config_path"
        exit 1
    fi

    if ! grep -q '^pwhash = "' "$config_path"; then
        log "Could not find a pwhash entry in $config_path"
        exit 1
    fi

    if ! grep -q "pwhash = \"${placeholder}\"" "$config_path"; then
        log "==> Zallet RPC pwhash already generated, skipping."
        return
    fi

    ensure_openssl

    salt="$(openssl rand -hex 16)"
    hash="$(printf '%s' "$rpc_password" | openssl dgst -sha256 -mac HMAC -macopt "key:$salt" | awk '{print $NF}')"

    if [ -z "$hash" ]; then
        log "Failed to generate zallet RPC password hash"
        exit 1
    fi

    pwhash="${salt}\$${hash}"
    tmp="$(mktemp "${TMPDIR:-/tmp}/zallet.toml.XXXXXX")"

    sed -E "s|^pwhash = \".*\"$|pwhash = \"${pwhash}\"|" "$config_path" > "$tmp"
    mv "$tmp" "$config_path"

    log "==> Generated zallet RPC pwhash in ${CONFIG_DIR}/zallet.toml"
}

require_compose_v2

DOCKER="docker"
if ! docker info > /dev/null 2>&1; then
    DOCKER="sudo -E docker"
    COMPOSE="sudo -E $COMPOSE"
fi

cd "$REPO_ROOT"

"$SCRIPT_DIR/setup-network.sh" regtest
update_zallet_rpc_pwhash

# Clean up any leftover containers from previous runs.
$COMPOSE down --remove-orphans 2>/dev/null || true

echo "==> Starting Zebra in regtest mode..."
$COMPOSE up -d zebra

echo "==> Waiting for Zebra RPC to be ready..."
until curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
    "http://127.0.0.1:${ZEBRA_HOST_RPC}" > /dev/null 2>&1; do
  echo "   Zebra not ready yet, retrying..."
  sleep 2
done
echo "   Zebra is ready."

echo "==> Mining 2 blocks (NU5/Orchard activates at height 2 to match Zaino's regtest defaults)..."
curl -s -u zebra:zebra \
    -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"generate","params":[2],"id":1}' \
    "http://127.0.0.1:${ZEBRA_HOST_RPC}" | grep -q '"result"'
echo "   Blocks mined."

# Compose names the Zallet data volume as ${COMPOSE_PROJECT_NAME}-zallet.
ZALLET_VOLUME="${PROJECT}-zallet"

echo "==> Running init-wallet-encryption..."
# Remove stale lock file and wallet database if present (left by a previous
# interrupted run). wallet.db will be recreated with the correct schema by
# init-wallet-encryption; leaving a stale one causes a schema mismatch error.
$DOCKER run --rm -v "${ZALLET_VOLUME}:/data" busybox \
    sh -c 'rm -f /data/.lock /data/wallet.db'

# generate-mnemonic stores an age-encrypted file; if one exists the full init
# sequence has already completed successfully.
ALREADY_INIT=$($DOCKER run --rm -v "${ZALLET_VOLUME}:/data" busybox \
    sh -c 'ls /data/*.age 2>/dev/null | wc -l')
if [ "${ALREADY_INIT:-0}" -gt 0 ]; then
    echo "   Wallet already initialized, skipping."
else
    $COMPOSE run --rm zallet --datadir /var/lib/zallet --config /etc/zallet/zallet.toml init-wallet-encryption
    echo "==> Running generate-mnemonic..."
    $COMPOSE run --rm zallet --datadir /var/lib/zallet --config /etc/zallet/zallet.toml generate-mnemonic
fi

echo "==> Stopping Zebra (will be restarted by docker compose up -d)..."
$COMPOSE down

echo ""
echo "Wallet initialized. Now run:"
echo "   docker compose --env-file .env.regtest up -d"
echo "   Router available at http://127.0.0.1:8181"
echo "   Zaino gRPC available at 127.0.0.1:${ZAINO_HOST_GRPC}"
