#!/usr/bin/env bash
# Test timeout behavior -- verify server responds within reasonable time
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

echo "=== Timeout Tests ==="

# Test 1: Simple pipeline should complete quickly
echo "--- Test: Simple pipeline completes within 5s ---"
start=$(python3 -c "import time; print(int(time.time()*1000))")

request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source, 'inputs': {'a': 42, 'b': 7, 'f': 3.14}}))
" "$REPO_DIR/pipelines/stdlib-math.cst")

result=$(curl -s --max-time 5 -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

end=$(python3 -c "import time; print(int(time.time()*1000))")
elapsed=$((end - start))

success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

if [ "$success" = "true" ] && [ "$elapsed" -lt 5000 ]; then
  echo "  PASS: Completed in ${elapsed}ms (< 5000ms)"
  PASS=$((PASS+1))
else
  echo "  FAIL: Timed out or failed (${elapsed}ms)"
  FAIL=$((FAIL+1))
fi

# Test 2: Complex pipeline should still complete in reasonable time
echo "--- Test: Complex pipeline completes within 10s ---"
start=$(python3 -c "import time; print(int(time.time()*1000))")

request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source, 'inputs': {'numbers': [1,2,3,4,5,6,7,8,9,10]}}))
" "$REPO_DIR/pipelines/lambda-filter.cst")

result=$(curl -s --max-time 10 -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

end=$(python3 -c "import time; print(int(time.time()*1000))")
elapsed=$((end - start))

success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

if [ "$success" = "true" ] && [ "$elapsed" -lt 10000 ]; then
  echo "  PASS: Completed in ${elapsed}ms (< 10000ms)"
  PASS=$((PASS+1))
else
  echo "  FAIL: Timed out or failed (${elapsed}ms)"
  FAIL=$((FAIL+1))
fi

# Test 3: Verify server health after timeout tests
echo "--- Test: Server health after timeout tests ---"
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
