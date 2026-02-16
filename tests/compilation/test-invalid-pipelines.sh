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
  result=$(curl -s -X POST "$BASE_URL/compile" \
    -H "Content-Type: text/plain" \
    --data-binary @"$pipeline")

  # These should produce errors — success means the test passes
  if echo "$result" | grep -qi "error"; then
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
