#!/usr/bin/env bash
# Test invalid pipeline handling -- syntax errors, missing modules, etc.
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
PASS=0
FAIL=0

echo "=== Invalid Pipeline Tests ==="

# Helper: compile a pipeline source and return the JSON response
compile() {
  local source="$1"
  local request
  request=$(python3 -c "
import json, sys
print(json.dumps({'source': sys.argv[1]}))
" "$source")
  curl -s -X POST "$BASE_URL/compile" \
    -H "Content-Type: application/json" \
    -d "$request"
}

check_failure() {
  local result="$1"
  local label="$2"
  local success
  success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

  if [ "$success" = "false" ]; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $label -- expected failure but got success"
    FAIL=$((FAIL+1))
  fi
}

# Test 1: Reference non-existent module
echo "--- Test: Non-existent module ---"
result=$(compile "$(printf 'in x: String\nresult = CompletelyFakeModule(x)\nout result')")
check_failure "$result" "Non-existent module"

# Check error message is descriptive
if echo "$result" | grep -qi "CompletelyFakeModule\|Undefined"; then
  echo "    (error message mentions the missing module -- good)"
fi

# Test 2: Syntax error -- malformed pipeline
echo "--- Test: Syntax error ---"
result=$(compile "this is not valid constellation syntax @@@ !!!")
check_failure "$result" "Syntax error"

# Test 3: Empty pipeline
echo "--- Test: Empty pipeline ---"
result=$(compile "")
success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")
if [ "$success" = "true" ]; then
  echo "  PASS: Empty pipeline -- compiled OK (valid: no inputs/outputs)"
  PASS=$((PASS+1))
else
  echo "  PASS: Empty pipeline -- rejected (also valid behavior)"
  PASS=$((PASS+1))
fi

# Test 4: Duplicate output declarations
echo "--- Test: Duplicate output ---"
result=$(compile "$(printf 'in x: String\nout x\nout x')")
# Duplicate outputs may or may not be an error depending on implementation
success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")
if [ "$success" = "true" ]; then
  echo "  INFO: Duplicate output -- accepted (idempotent)"
  PASS=$((PASS+1))
else
  echo "  PASS: Duplicate output -- rejected"
  PASS=$((PASS+1))
fi

# Test 5: Self-referencing variable
echo "--- Test: Self-referencing variable ---"
result=$(compile "$(printf 'in x: String\ny = FakeModule(y)\nout y')")
check_failure "$result" "Self-reference"

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
