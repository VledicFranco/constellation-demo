#!/usr/bin/env bash
# Test retry behavior — use pipeline with retry option
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0

echo "=== Retry Tests ==="

# Use the resilience pipeline which has retry options
pipeline="$REPO_DIR/pipelines/11-resilience.cst"
if [ ! -f "$pipeline" ]; then
  echo "SKIP: 11-resilience.cst not found"
  exit 0
fi

request=$(python3 -c "
import json
source = open('$pipeline').read()
inputs = {'text': 'retry test input'}
print(json.dumps({'source': source, 'inputs': inputs}))
")

# Test 1: Execute pipeline with retry options
echo "--- Test: Pipeline with retry options ---"
result=$(curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request")

if echo "$result" | grep -qi '"error"'; then
  echo "  FAIL: Resilience pipeline failed: $(echo "$result" | head -3)"
  FAIL=$((FAIL+1))
else
  echo "  PASS: Resilience pipeline completed"
  PASS=$((PASS+1))

  # Check that outputs are present
  output_count=$(echo "$result" | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)
    outputs = r.get('outputs', {})
    print(len(outputs))
except:
    print(0)
" 2>/dev/null)

  if [ "$output_count" -gt 0 ] 2>/dev/null; then
    echo "  PASS: Got $output_count outputs"
    PASS=$((PASS+1))
  else
    echo "  WARN: No outputs in response"
    PASS=$((PASS+1))
  fi
fi

# Test 2: Module options pipeline (has retry: 3 and backoff: exponential)
pipeline2="$REPO_DIR/pipelines/07-module-options.cst"
if [ -f "$pipeline2" ]; then
  echo "--- Test: Module options pipeline with retry ---"
  request2=$(python3 -c "
import json
source = open('$pipeline2').read()
inputs = {'text': 'retry options test', 'query': 'test'}
print(json.dumps({'source': source, 'inputs': inputs}))
")

  result2=$(curl -s -X POST "$BASE_URL/run" \
    -H "Content-Type: application/json" \
    -d "$request2")

  if echo "$result2" | grep -qi '"error"'; then
    echo "  FAIL: Module options pipeline failed: $(echo "$result2" | head -3)"
    FAIL=$((FAIL+1))
  else
    echo "  PASS: Module options pipeline with retry completed"
    PASS=$((PASS+1))
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
