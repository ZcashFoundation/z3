#!/usr/bin/env bash
# setup-network.sh: idempotent first-run setup for a z3 network.
#
# Copies per-network .example TOML templates into the live gitignored paths
# that docker-compose.yml mounts; generates a Zallet identity and shared TLS
# cert if missing.
#
# Usage:
#   ./scripts/setup-network.sh <mainnet|testnet|regtest>
#
# Safe to re-run: every step skips if its output already exists. The live
# TOMLs and identity file are local and gitignored.
#
# For regtest, this script only handles file setup; the operational steps
# (mining the activation block, generating the wallet mnemonic) live in
# scripts/regtest-init.sh, which delegates here first.

set -euo pipefail

NETWORK="${1:-}"
case "$NETWORK" in
    mainnet|testnet|regtest) ;;
    *)
        echo "Usage: $0 <mainnet|testnet|regtest>" >&2
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config/$NETWORK"

log() { printf '%s\n' "$*"; }

copy_template() {
    local file="$1"
    local example="$CONFIG_DIR/$file.example"
    local active="$CONFIG_DIR/$file"

    if [ -f "$active" ]; then
        log "==> $NETWORK/$file: present, leaving operator copy untouched."
        return
    fi

    if [ ! -f "$example" ]; then
        log "FAIL: missing template $example" >&2
        exit 1
    fi

    cp "$example" "$active"
    log "==> $NETWORK/$file: created from .example template."
}

ensure_identity() {
    local identity="$CONFIG_DIR/zallet_identity.txt"

    if [ -f "$identity" ]; then
        log "==> $NETWORK/zallet_identity.txt: present."
        return
    fi

    if ! command -v rage-keygen >/dev/null 2>&1; then
        log "FAIL: rage-keygen not found." >&2
        log "      Install rage from https://github.com/str4d/rage/releases" >&2
        exit 1
    fi

    rage-keygen -o "$identity"
    chmod 600 "$identity"
    log "==> $NETWORK/zallet_identity.txt: generated."
}

ensure_tls() {
    local cert="$REPO_ROOT/config/tls/zaino.crt"
    local key="$REPO_ROOT/config/tls/zaino.key"

    if [ -f "$cert" ] && [ -f "$key" ]; then
        log "==> tls/zaino.{crt,key}: present."
        return
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        log "FAIL: openssl not found." >&2
        exit 1
    fi

    mkdir -p "$REPO_ROOT/config/tls"
    openssl req -x509 -newkey rsa:4096 \
        -keyout "$key" -out "$cert" \
        -sha256 -days 365 -nodes -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:zaino,IP:127.0.0.1" 2>/dev/null
    log "==> tls/zaino.{crt,key}: generated (self-signed, 1 year)."
}

copy_compose_override() {
    # testnet and regtest load docker-compose.<network>.override.yml from
    # COMPOSE_FILE; the file has to exist for compose not to error. mainnet
    # auto-loads docker-compose.override.yml only when present, so we skip it.
    local file="docker-compose.$NETWORK.override.yml"
    local example="$REPO_ROOT/$file.example"
    local active="$REPO_ROOT/$file"

    if [ -f "$active" ]; then
        log "==> $file: present, leaving operator copy untouched."
        return
    fi
    if [ ! -f "$example" ]; then
        log "==> $file: no template at $example.example, skipping."
        return
    fi
    cp "$example" "$active"
    log "==> $file: created from .example template (empty placeholder; edit freely)."
}

mkdir -p "$CONFIG_DIR"

copy_template zaino.toml
copy_template zallet.toml
# Regtest needs a Zebra TOML to activate NU5/NU6 at heights Zaino expects.
# Mainnet and testnet use Zebra's built-in network defaults.
if [ "$NETWORK" = "regtest" ]; then
    copy_template zebra.toml
fi
# testnet and regtest auto-load a per-network override via COMPOSE_FILE;
# create the live override file from the template if missing so compose
# does not error on a missing file.
if [ "$NETWORK" = "testnet" ] || [ "$NETWORK" = "regtest" ]; then
    copy_compose_override
fi
ensure_identity
ensure_tls

log
log "Setup complete for $NETWORK."
log "Next: docker compose --env-file .env.$NETWORK up -d zebra"
