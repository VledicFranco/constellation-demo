#!/usr/bin/env bash
# Demonstrate module listing and health checks
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "=== Version Lifecycle Demo ==="

echo "Health check:"
curl -s "$BASE_URL/health"
echo ""

echo "Module list:"
curl -s "$BASE_URL/modules" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/modules"
echo ""

echo "Metrics:"
curl -s "$BASE_URL/metrics" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/metrics"
echo ""
