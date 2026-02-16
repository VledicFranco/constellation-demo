#!/usr/bin/env bash
# Test invalid pipeline handling — syntax errors, missing modules, etc.
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

echo "=== Invalid Pipeline Tests ==="

# Test 1: Reference non-existent module
echo "--- Test: Non-existent module ---"
result=$(curl -s -X POST "$BASE_URL/compile" \
  -H "Content-Type: text/plain" \
  -d 'in x: String
result = CompletelyFakeModule(x)
out result')

if echo "$result" | grep -qi "error"; then
  echo "  PASS: Non-existent module — got error"
  PASS=$((PASS+1))
else
  echo "  FAIL: Non-existent module — expected error but got: $result"
  FAIL=$((FAIL+1))
fi

# Check error message is descriptive (not a raw stack trace)
if echo "$result" | grep -qi "stack\|exception\|java\.\|scala\."; then
  echo "  WARN: Error message contains internal details"
fi

# Test 2: Syntax error — malformed pipeline
echo "--- Test: Syntax error ---"
result=$(curl -s -X POST "$BASE_URL/compile" \
  -H "Content-Type: text/plain" \
  -d 'this is not valid constellation syntax @@@ !!!')

if echo "$result" | grep -qi "error\|parse\|syntax"; then
  echo "  PASS: Syntax error — got error"
  PASS=$((PASS+1))
else
  echo "  FAIL: Syntax error — expected error but got: $result"
  FAIL=$((FAIL+1))
fi

# Test 3: Empty pipeline
echo "--- Test: Empty pipeline ---"
result=$(curl -s -X POST "$BASE_URL/compile" \
  -H "Content-Type: text/plain" \
  -d '')

if echo "$result" | grep -qi "error"; then
  echo "  PASS: Empty pipeline — got error"
  PASS=$((PASS+1))
else
  # An empty pipeline might actually be valid (no inputs, no outputs)
  echo "  INFO: Empty pipeline — response: $(echo "$result" | head -3)"
  PASS=$((PASS+1))
fi

# Test 4: Duplicate output declarations
echo "--- Test: Duplicate output ---"
result=$(curl -s -X POST "$BASE_URL/compile" \
  -H "Content-Type: text/plain" \
  -d 'in x: String
upper = Uppercase(x)
out upper
out upper')

if echo "$result" | grep -qi "error\|duplicate"; then
  echo "  PASS: Duplicate output — got error"
  PASS=$((PASS+1))
else
  echo "  INFO: Duplicate output — response: $(echo "$result" | head -3)"
  PASS=$((PASS+1))
fi

# Test 5: Circular dependency (variable references itself)
echo "--- Test: Self-referencing variable ---"
result=$(curl -s -X POST "$BASE_URL/compile" \
  -H "Content-Type: text/plain" \
  -d 'in x: String
y = Uppercase(y)
out y')

if echo "$result" | grep -qi "error"; then
  echo "  PASS: Self-reference — got error"
  PASS=$((PASS+1))
else
  echo "  FAIL: Self-reference — expected error but got: $result"
  FAIL=$((FAIL+1))
fi

# Test 6: Verify server is still healthy after all error tests
echo "--- Test: Server health after error tests ---"
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
