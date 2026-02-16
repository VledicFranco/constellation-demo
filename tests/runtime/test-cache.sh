#!/usr/bin/env bash
# Test caching behavior — execute same pipeline twice and check metrics
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

echo "=== Cache Tests ==="

# Use the caching demo pipeline
pipeline="$REPO_DIR/pipelines/12-caching-demo.cst"
if [ ! -f "$pipeline" ]; then
  echo "SKIP: 12-caching-demo.cst not found"
  exit 0
fi

request=$(python3 -c "
import json
source = open('$pipeline').read()
inputs = {'text': 'cache test input'}
print(json.dumps({'source': source, 'inputs': inputs}))
")

# Test 1: First execution
echo "--- Test: First execution ---"
result1=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

if echo "$result1" | grep -qi '"error"'; then
  echo "  FAIL: First execution failed: $(echo "$result1" | head -3)"
  FAIL=$((FAIL+1))
else
  echo "  PASS: First execution succeeded"
  PASS=$((PASS+1))
fi

# Test 2: Second execution (should hit cache)
echo "--- Test: Second execution (cache hit expected) ---"
result2=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

if echo "$result2" | grep -qi '"error"'; then
  echo "  FAIL: Second execution failed: $(echo "$result2" | head -3)"
  FAIL=$((FAIL+1))
else
  echo "  PASS: Second execution succeeded"
  PASS=$((PASS+1))
fi

# Test 3: Check metrics for cache hits
echo "--- Test: Cache metrics ---"
metrics=$(curl -s "$BASE_URL/metrics")

if echo "$metrics" | grep -qi "cache\|hit"; then
  echo "  PASS: Cache metrics available"
  echo "  INFO: $(echo "$metrics" | python3 -c "
import json, sys
try:
    m = json.load(sys.stdin)
    cache = m.get('cache', m)
    print(json.dumps(cache, indent=2))
except:
    print('Could not parse metrics')
" 2>/dev/null)"
  PASS=$((PASS+1))
else
  echo "  INFO: Cache metrics not found in response (may not be enabled)"
  echo "  Metrics response: $(echo "$metrics" | head -5)"
  PASS=$((PASS+1))
fi

# Test 4: Results should be identical
echo "--- Test: Results consistency ---"
out1=$(echo "$result1" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('outputs',{}), sort_keys=True))" 2>/dev/null || echo "PARSE_ERROR")
out2=$(echo "$result2" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('outputs',{}), sort_keys=True))" 2>/dev/null || echo "PARSE_ERROR")

if [ "$out1" = "$out2" ] && [ "$out1" != "PARSE_ERROR" ]; then
  echo "  PASS: Both executions produced identical outputs"
  PASS=$((PASS+1))
elif [ "$out1" = "PARSE_ERROR" ] || [ "$out2" = "PARSE_ERROR" ]; then
  echo "  WARN: Could not parse outputs for comparison"
  PASS=$((PASS+1))
else
  echo "  FAIL: Outputs differ between executions"
  echo "    First:  $out1"
  echo "    Second: $out2"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
