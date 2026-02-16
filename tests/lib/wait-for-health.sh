#!/usr/bin/env bash
# Wait for constellation server health check to pass
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
TIMEOUT="${1:-60}"
INTERVAL=5
ELAPSED=0

echo "Waiting for server at $BASE_URL/health (timeout: ${TIMEOUT}s)..."

while [ $ELAPSED -lt $TIMEOUT ]; do
  if curl -sf "$BASE_URL/health" > /dev/null 2>&1; then
    echo "Server is healthy!"
    exit 0
  fi
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "  Still waiting... (${ELAPSED}s)"
done

echo "ERROR: Server not healthy after ${TIMEOUT}s"
exit 1
