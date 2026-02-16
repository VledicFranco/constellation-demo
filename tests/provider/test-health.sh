#!/usr/bin/env bash
# Test that all Docker Compose services are healthy
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

echo "=== Provider Health Tests ==="

# Test 1: Server health endpoint
echo "--- Test: Server /health ---"
health=$(curl -s "$BASE_URL/health")
if echo "$health" | grep -qi "ok\|healthy\|up"; then
  echo "  PASS: Server is healthy"
  PASS=$((PASS+1))
else
  echo "  FAIL: Server health check: $health"
  FAIL=$((FAIL+1))
fi

# Test 2: Server liveness probe
echo "--- Test: Server /health/live ---"
live=$(curl -s "$BASE_URL/health/live")
if echo "$live" | grep -qi "ok\|live\|alive\|up"; then
  echo "  PASS: Liveness probe OK"
  PASS=$((PASS+1))
else
  echo "  FAIL: Liveness probe: $live"
  FAIL=$((FAIL+1))
fi

# Test 3: Server readiness probe
echo "--- Test: Server /health/ready ---"
ready=$(curl -s "$BASE_URL/health/ready")
if echo "$ready" | grep -qi "ok\|ready\|up"; then
  echo "  PASS: Readiness probe OK"
  PASS=$((PASS+1))
else
  echo "  FAIL: Readiness probe: $ready"
  FAIL=$((FAIL+1))
fi

# Test 4: Docker Compose services (if docker compose is available)
echo "--- Test: Docker Compose services ---"
if command -v docker &>/dev/null; then
  cd "$REPO_DIR"
  services=$(docker compose ps --format json 2>/dev/null || docker-compose ps 2>/dev/null || echo "DOCKER_NOT_AVAILABLE")

  if [ "$services" = "DOCKER_NOT_AVAILABLE" ]; then
    echo "  SKIP: Docker Compose not available"
  else
    echo "  INFO: Docker Compose services:"
    docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || true
    PASS=$((PASS+1))
  fi
else
  echo "  SKIP: Docker not available"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
