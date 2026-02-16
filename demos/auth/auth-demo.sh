#!/usr/bin/env bash
# Demonstrate API authentication (when configured)
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "=== Auth Demo ==="

echo "Public endpoints (no auth needed):"
echo "  Health:    $(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/health")"
echo "  Liveness:  $(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/health/live")"
echo "  Readiness: $(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/health/ready")"

echo ""
echo "API endpoints:"
echo "  Modules:   $(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/modules")"
echo "  Compile:   $(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/compile" -H 'Content-Type: text/plain' -d 'in x: Int
out x')"
