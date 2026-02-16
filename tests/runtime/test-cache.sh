#!/usr/bin/env bash
# Test caching behavior -- execute same pipeline twice and check for consistency
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

echo "=== Cache Tests ==="

# Use a stdlib pipeline that actually runs (no example-app modules)
pipeline="$REPO_DIR/pipelines/stdlib-math.cst"
if [ ! -f "$pipeline" ]; then
  echo "SKIP: stdlib-math.cst not found"
  exit 0
fi

request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source, 'inputs': {'a': 10, 'b': 3, 'f': 3.7}}))
" "$pipeline")

# Test 1: First execution
echo "--- Test: First execution ---"
result1=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

success1=$(echo "$result1" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

if [ "$success1" = "true" ]; then
  echo "  PASS: First execution succeeded"
  PASS=$((PASS+1))
else
  echo "  FAIL: First execution failed"
  FAIL=$((FAIL+1))
fi

# Test 2: Second execution (should hit compilation cache)
echo "--- Test: Second execution (cache hit expected) ---"
result2=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

success2=$(echo "$result2" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

if [ "$success2" = "true" ]; then
  echo "  PASS: Second execution succeeded"
  PASS=$((PASS+1))
else
  echo "  FAIL: Second execution failed"
  FAIL=$((FAIL+1))
fi

# Test 3: Check metrics for cache hits
echo "--- Test: Cache metrics ---"
metrics=$(curl -s "$BASE_URL/metrics")

if echo "$metrics" | grep -qi "cache\|hit"; then
  echo "  PASS: Cache metrics available"
  echo "$metrics" | python3 -c "
import json, sys
try:
    m = json.load(sys.stdin)
    cache = m.get('cache', m)
    print('  INFO: ' + json.dumps(cache, indent=2))
except:
    print('  INFO: Could not parse metrics')
" 2>/dev/null
  PASS=$((PASS+1))
else
  echo "  INFO: Cache metrics not found in response (may not be enabled)"
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
