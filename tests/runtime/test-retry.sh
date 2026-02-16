#!/usr/bin/env bash
# Test retry behavior -- verify pipeline options syntax compiles and executes
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
PASS=0
FAIL=0

echo "=== Retry Tests ==="

# Test 1: Pipeline with retry-like pattern (execute twice, verify consistency)
echo "--- Test: Repeated execution consistency ---"
request=$(python3 -c "
import json
source = '''use stdlib.math
in a: Int
in b: Int
sum = add(a, b)
product = multiply(a, b)
out sum
out product'''
print(json.dumps({'source': source, 'inputs': {'a': 7, 'b': 3}}))
")

result1=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

result2=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

out1=$(echo "$result1" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('outputs',{}), sort_keys=True))" 2>/dev/null || echo "ERR")
out2=$(echo "$result2" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('outputs',{}), sort_keys=True))" 2>/dev/null || echo "ERR")

if [ "$out1" = "$out2" ] && [ "$out1" != "ERR" ]; then
  echo "  PASS: Repeated executions produce identical results"
  PASS=$((PASS+1))
else
  echo "  FAIL: Results differ or parsing error"
  FAIL=$((FAIL+1))
fi

# Test 2: Recovery after error -- server should handle errors and stay healthy
echo "--- Test: Recovery after bad request ---"
bad_result=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d '{"source":"in x: Int\nresult = NonExistent(x)\nout result","inputs":{"x":1}}')

# Server should still work after error
good_result=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

success=$(echo "$good_result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

if [ "$success" = "true" ]; then
  echo "  PASS: Server recovered after error"
  PASS=$((PASS+1))
else
  echo "  FAIL: Server did not recover after error"
  FAIL=$((FAIL+1))
fi

# Test 3: Server health
echo "--- Test: Server health ---"
health=$(curl -s "$BASE_URL/health")
if echo "$health" | grep -qi "ok\|healthy\|up"; then
  echo "  PASS: Server still healthy"
  PASS=$((PASS+1))
else
  echo "  FAIL: Server health check failed"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
