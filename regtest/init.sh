#!/usr/bin/env bash
# init.sh - Initialize the regtest wallet for the first time.
#
# Run this once before `docker compose up -d`.
# Safe to re-run: skips steps if already done.
#
# Requirements:
#   - Docker with the z3_zallet:local image built (cd ../../ && docker compose build zallet)
#   - No running z3_regtest_* containers

set -euo pipefail

log() {
    printf '%s\n' "$*"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK=regtest_regtest_net

ensure_rage() {
    if command -v rage-keygen > /dev/null 2>&1; then
        log "rage already installed"
        return
    fi

    log "rage-keygen is required to generate a local zallet identity."
    log "Install it, then re-run this script:"
    log "  macOS: brew install rage"
    log "  Debian/Ubuntu: install rage from https://github.com/str4d/rage/releases or provide rage-keygen in PATH"
    exit 1
}

ensure_local_identity() {
    local identity_path="$SCRIPT_DIR/config/zallet_identity.txt"

    if [ -f "$identity_path" ]; then
        log "==> Reusing existing local zallet identity..."
        return
    fi

    ensure_rage

    log "==> Generating local zallet identity..."
    mkdir -p "$SCRIPT_DIR/config"
    rage-keygen -o "$identity_path"
    chmod 600 "$identity_path"
}

ensure_openssl() {
    if command -v openssl > /dev/null 2>&1; then
        return
    fi

    log "openssl is required to generate a local zallet RPC password hash."
    log "Install OpenSSL, then re-run this script."
    exit 1
}

update_zallet_rpc_pwhash() {
    local config_path="$SCRIPT_DIR/config/zallet.toml"
    local rpc_password="${RPC_PASSWORD:-zebra}"
    local salt
    local hash
    local pwhash
    local tmp

    ensure_openssl

    if [ ! -f "$config_path" ]; then
        log "Missing zallet config: $config_path"
        exit 1
    fi

    if ! grep -q '^pwhash = "' "$config_path"; then
        log "Could not find a pwhash entry in $config_path"
        exit 1
    fi

    salt="$(openssl rand -hex 16)"
    hash="$(printf '%s' "$rpc_password" | openssl dgst -sha256 -mac HMAC -macopt "key:$salt" | awk '{print $2}')"

    if [ -z "$hash" ]; then
        log "Failed to generate zallet RPC password hash"
        exit 1
    fi

    pwhash="${salt}\$${hash}"
    tmp="$(mktemp "${TMPDIR:-/tmp}/zallet.toml.XXXXXX")"

    sed -E "s|^pwhash = \".*\"$|pwhash = \"${pwhash}\"|" "$config_path" > "$tmp"
    mv "$tmp" "$config_path"

    log "==> Updated zallet RPC pwhash in config/zallet.toml"
}

# Use sudo for docker if needed
DOCKER="docker"
if ! docker info > /dev/null 2>&1; then
    DOCKER="sudo -E docker"
fi

cd "$SCRIPT_DIR"

ensure_local_identity
update_zallet_rpc_pwhash

echo "==> Starting Zebra in regtest mode..."
$DOCKER compose up -d zebra

echo "==> Waiting for Zebra RPC to be ready..."
until curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}' \
    http://127.0.0.1:18232 > /dev/null 2>&1; do
  echo "   Zebra not ready yet, retrying..."
  sleep 2
done
echo "   Zebra is ready."

echo "==> Mining 1 block (required for Orchard activation at height 1)..."
curl -s -u zebra:zebra \
    -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"generate","params":[1],"id":1}' \
    http://127.0.0.1:18232 | grep -q '"result"'
echo "   Block mined."

echo "==> Running init-wallet-encryption..."
# Remove stale lock file if present (left by a previous interrupted run)
$DOCKER run --rm -v zallet_regtest_data:/data busybox \
    sh -c 'rm -f /data/.lock'
# Check if wallet already initialized by looking for the wallet database
ALREADY_INIT=$($DOCKER run --rm -v zallet_regtest_data:/data busybox \
    sh -c 'ls /data/*.sqlite /data/*.age 2>/dev/null | wc -l')
if [ "${ALREADY_INIT:-0}" -gt 0 ]; then
    echo "   Wallet already initialized, skipping."
else
    $DOCKER compose run --rm zallet --datadir /var/lib/zallet init-wallet-encryption

    echo "==> Running generate-mnemonic..."
    $DOCKER compose run --rm zallet --datadir /var/lib/zallet generate-mnemonic
fi

echo "==> Stopping Zebra (will be restarted by docker compose up -d)..."
$DOCKER compose down

echo ""
echo "✅ Wallet initialized. Now run:"
echo "   sudo -E docker compose up -d"
echo "   # Router will be available at http://127.0.0.1:8181"
echo "   # Zaino gRPC will be available at 127.0.0.1:8137"
