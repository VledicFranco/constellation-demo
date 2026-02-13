#!/usr/bin/env bash
set -euo pipefail

# Check server health, metrics, modules, and pipelines
# Requires: constellation-server running on localhost:8080

SERVER="${CONSTELLATION_SERVER:-http://localhost:8080}"

echo "=== Constellation Health Check ==="
echo "Server: $SERVER"
echo ""

echo "--- Health ---"
curl -s "$SERVER/health" | jq .
echo ""

echo "--- Liveness ---"
curl -s "$SERVER/health/live" | jq .
echo ""

echo "--- Readiness ---"
curl -s "$SERVER/health/ready" | jq .
echo ""

echo "--- Metrics (JSON) ---"
curl -s "$SERVER/metrics" | jq '{
  cache: .cache,
  scheduler: .scheduler,
  lifecycle: .lifecycle
}' 2>/dev/null || curl -s "$SERVER/metrics"
echo ""

echo "--- Registered Modules ---"
curl -s "$SERVER/modules" | jq '.[].name' 2>/dev/null || curl -s "$SERVER/modules"
echo ""

echo "--- Stored Pipelines ---"
curl -s "$SERVER/pipelines" | jq '.[].name // .[].alias' 2>/dev/null || curl -s "$SERVER/pipelines"
echo ""

echo "=== Done ==="
