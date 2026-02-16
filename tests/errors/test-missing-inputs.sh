#!/usr/bin/env bash
# Test missing input handling -- submit pipelines without required inputs
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

echo "=== Missing Input Tests ==="

# Test 1: Pipeline that requires inputs, but provide none
echo "--- Test: No inputs provided ---"
request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source, 'inputs': {}}))
" "$REPO_DIR/pipelines/stdlib-math.cst" 2>&1) || true

result=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

has_error=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('error') or not d.get('success', False) or d.get('missingInputs'):
        print('yes')
    else:
        print('no')
except:
    print('yes')
" 2>/dev/null || echo "yes")

if [ "$has_error" = "yes" ]; then
  echo "  PASS: No inputs -- got error/missing inputs response"
  PASS=$((PASS+1))
else
  echo "  FAIL: No inputs -- expected error but got success"
  FAIL=$((FAIL+1))
fi

# Verify HTTP status is not 500 (should be 4xx or graceful error in JSON)
http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

if [ "$http_code" -lt 500 ]; then
  echo "  PASS: HTTP status $http_code (not 500)"
  PASS=$((PASS+1))
else
  echo "  FAIL: HTTP status $http_code (expected < 500)"
  FAIL=$((FAIL+1))
fi

# Test 2: Partial inputs -- provide some but not all required inputs
echo "--- Test: Partial inputs ---"
request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
# stdlib-math needs a, b -- only provide a
print(json.dumps({'source': source, 'inputs': {'a': 10}}))
" "$REPO_DIR/pipelines/stdlib-math.cst" 2>&1) || true

result=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

has_error=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if d.get('error') or not d.get('success', False) or d.get('missingInputs'):
        print('yes')
    else:
        print('no')
except:
    print('yes')
" 2>/dev/null || echo "yes")

if [ "$has_error" = "yes" ]; then
  echo "  PASS: Partial inputs -- got error/missing inputs response"
  PASS=$((PASS+1))
else
  echo "  FAIL: Partial inputs -- expected error but got success"
  FAIL=$((FAIL+1))
fi

# Test 3: Verify server is still healthy after error tests
echo "--- Test: Server health after errors ---"
health=$(curl -s "$BASE_URL/health")
if echo "$health" | grep -qi "ok\|healthy\|up"; then
  echo "  PASS: Server still healthy"
  PASS=$((PASS+1))
else
  echo "  FAIL: Server health check failed: $health"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
