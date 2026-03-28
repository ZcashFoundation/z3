#!/bin/bash
# Polls Zebra's readiness endpoint until it returns "ok"
# Use this script during initial sync to know when Zebra is ready

echo "Waiting for Zebra to sync..."
echo "This may take hours (mainnet: 24-72h, testnet: 2-12h)"
echo "You can safely Ctrl+C and check back later."
echo ""

while true; do
  response=$(curl -s http://127.0.0.1:8080/ready)
  if [ "$response" = "ok" ]; then
    echo ""
    echo "Zebra is ready! You can now start the remaining services:"
    echo "  docker compose up -d"
    break
  fi
  echo "$(date '+%H:%M:%S') - Not ready yet: $response"
  sleep 30
done
