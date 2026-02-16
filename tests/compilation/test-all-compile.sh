#!/usr/bin/env bash
# Test that all pipelines compile successfully
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0
ERRORS=""

echo "=== Compilation Tests ==="

for pipeline in "$REPO_DIR"/pipelines/*.cst; do
  name=$(basename "$pipeline")
  result=$(curl -s -X POST "$BASE_URL/compile" \
    -H "Content-Type: text/plain" \
    --data-binary @"$pipeline")

  # Check for compilation errors
  if echo "$result" | grep -qi "error"; then
    FAIL=$((FAIL+1))
    ERRORS="$ERRORS\n  FAIL: $name"
    echo "  FAIL: $name"
    echo "    $result" | head -5
  else
    PASS=$((PASS+1))
    echo "  PASS: $name"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo -e "Failures:$ERRORS"
  exit 1
fi
