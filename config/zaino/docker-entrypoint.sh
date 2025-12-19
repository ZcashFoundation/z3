#!/bin/sh
# WORKAROUND: Resolves Docker DNS hostname to IP before starting Zaino
# Zaino's ValidatorConfig currently requires SocketAddr format (IP:port),
# not hostname:port format needed for Docker service discovery.
#
# This workaround can be REMOVED once zaino PR #784 is merged

set -e

ZEBRA_HOST="${ZEBRA_HOST:-zebra}"
ZEBRA_PORT="${ZEBRA_PORT:-18232}"

echo "Resolving ${ZEBRA_HOST}..."
ZEBRA_IP=$(getent hosts "${ZEBRA_HOST}" | awk '{ print $1 }')

if [ -z "${ZEBRA_IP}" ]; then
    echo "ERROR: Could not resolve ${ZEBRA_HOST}"
    exit 1
fi

echo "Resolved ${ZEBRA_HOST} to ${ZEBRA_IP}"
export ZAINO_VALIDATOR_SETTINGS__VALIDATOR_JSONRPC_LISTEN_ADDRESS="${ZEBRA_IP}:${ZEBRA_PORT}"

exec /usr/local/bin/zainod "$@"
