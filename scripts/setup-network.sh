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
ZALLET_UID=1000

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

grant_zallet_uid_read() {
    local file="$1"

    # Zallet runs as uid 1000 (distroless image, no runtime chown), so it can
    # only read bind-mounted secrets if uid 1000 has read access. When the
    # operator's host uid is already 1000 the 0600 file is readable as-is;
    # otherwise grant uid 1000 read via POSIX ACL without widening to others.
    if [ "$(id -u)" -eq "$ZALLET_UID" ]; then
        return
    fi

    if command -v setfacl >/dev/null 2>&1 && setfacl -m "u:${ZALLET_UID}:r" "$file"; then
        return
    fi

    log "FAIL: cannot grant uid $ZALLET_UID read on $file (host uid $(id -u) != $ZALLET_UID)." >&2
    log "      zallet (uid $ZALLET_UID) could not read the file and would fail to start." >&2
    log "      Install the 'acl' package and run: setfacl -m u:${ZALLET_UID}:r $file" >&2
    log "      (or 'chmod 644 $file' to allow all local users)." >&2
    exit 1
}

ensure_identity() {
    local identity="$CONFIG_DIR/zallet_identity.txt"

    if [ -f "$identity" ]; then
        log "==> $NETWORK/zallet_identity.txt: present."
    elif ! command -v rage-keygen >/dev/null 2>&1; then
        log "FAIL: rage-keygen not found." >&2
        log "      Install rage from https://github.com/str4d/rage/releases" >&2
        exit 1
    else
        rage-keygen -o "$identity"
        log "==> $NETWORK/zallet_identity.txt: generated."
    fi

    chmod 600 "$identity"
    grant_zallet_uid_read "$identity"
    log "==> $NETWORK/zallet_identity.txt: ensured readable by zallet uid $ZALLET_UID."
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
ensure_identity

log
log "Setup complete for $NETWORK."
log "Next: docker compose --env-file .env.$NETWORK up -d zebra"
