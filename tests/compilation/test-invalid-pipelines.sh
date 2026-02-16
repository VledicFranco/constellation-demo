#!/usr/bin/env bash
# Test that invalid pipelines produce compilation errors
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
ERRORS=""

echo "=== Invalid Pipeline Compilation Tests ==="

for pipeline in "$SCRIPT_DIR"/invalid/*.cst; do
  name=$(basename "$pipeline")

  # Build JSON request using Python
  request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source}))
" "$pipeline" 2>&1) || true

  if [ -z "$request" ]; then
    FAIL=$((FAIL+1))
    echo "  FAIL: $name (could not read pipeline)"
    continue
  fi

  result=$(curl -s -X POST "$BASE_URL/compile" \
    -H "Content-Type: application/json" \
    -d "$request")

  # These should produce errors -- success: false means the test passes
  success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

  if [ "$success" = "false" ]; then
    PASS=$((PASS+1))
    echo "  PASS: $name (correctly rejected)"
  else
    FAIL=$((FAIL+1))
    ERRORS="$ERRORS\n  FAIL: $name (should have been rejected)"
    echo "  FAIL: $name (should have been rejected)"
    echo "    $result" | head -3
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo -e "Failures:$ERRORS"
  exit 1
fi
