#!/usr/bin/env bash
# Polls Zebra's readiness endpoint until it returns "ok".
# Run during initial sync to know when Zebra is ready for the rest of the stack.
#
# Usage:
#   ./scripts/check-zebra-readiness.sh                  # mainnet (port 8080)
#   ./scripts/check-zebra-readiness.sh 18080            # testnet
#   ./scripts/check-zebra-readiness.sh 28080            # regtest

set -euo pipefail

PORT="${1:-8080}"
URL="http://127.0.0.1:${PORT}/ready"

# Map the health port to the matching env file so the success message tells
# the operator the right docker compose invocation.
case "$PORT" in
  8080)  ENV_FILE=".env.mainnet" ;;
  18080) ENV_FILE=".env.testnet" ;;
  28080) ENV_FILE=".env.regtest" ;;
  *)     ENV_FILE=".env.<network>" ;;
esac

echo "Polling ${URL} every 30s."
echo "Initial sync takes hours: mainnet 24-72h, testnet 2-12h."
echo "Safe to Ctrl+C and re-run later; Zebra keeps syncing in the background."
echo

while true; do
  response="$(curl -s "$URL" || true)"
  if [ "$response" = "ok" ]; then
    echo
    echo "Zebra is ready. Bring up the rest of the stack with:"
    echo "  docker compose --env-file ${ENV_FILE} up -d"
    exit 0
  fi
  echo "$(date '+%H:%M:%S') - not ready yet: ${response:-no response}"
  sleep 30
done
