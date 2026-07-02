#!/usr/bin/env bash
# setup-network.sh: idempotent first-run setup for a z3 network.
#
# Copies per-network .example TOML templates into the live gitignored paths
# that docker-compose.yml mounts, and ensures they are readable by the service
# containers.
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
        log "==> $NETWORK/$file: present, leaving contents untouched."
        return
    fi

    if [ ! -f "$example" ]; then
        log "FAIL: missing template $example" >&2
        exit 1
    fi

    cp "$example" "$active"
    log "==> $NETWORK/$file: created from .example template."
}

ensure_toml_readable() {
    local file="$1"
    local config="$CONFIG_DIR/$file"

    if [ ! -f "$config" ]; then
        log "FAIL: missing config $config" >&2
        exit 1
    fi

    chmod 644 "$config"
    log "==> $NETWORK/$file: ensured readable by service containers."
}

mkdir -p "$CONFIG_DIR"

copy_template zaino.toml
copy_template zallet.toml
# Regtest needs a Zebra TOML to activate NU5/NU6 at heights Zaino expects.
# Mainnet and testnet use Zebra's built-in network defaults.
if [ "$NETWORK" = "regtest" ]; then
    copy_template zebra.toml
fi
ensure_toml_readable zaino.toml
ensure_toml_readable zallet.toml
if [ "$NETWORK" = "regtest" ]; then
    ensure_toml_readable zebra.toml
fi

log
log "Setup complete for $NETWORK."
log "Next: docker compose --env-file .env.$NETWORK up -d zebra"
