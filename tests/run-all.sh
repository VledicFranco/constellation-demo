#!/usr/bin/env bash
# Master test runner -- finds and runs all test scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://localhost:8080}"
export BASE_URL

TOTAL_PASS=0
TOTAL_FAIL=0
SUITES_RUN=0
SUITES_FAIL=0

echo "============================================"
echo "  Constellation Demo Test Suite"
echo "============================================"
echo ""

# Wait for server
"$SCRIPT_DIR/lib/wait-for-health.sh" 60

echo ""

# Run each test suite
for suite_dir in compilation execution errors provider runtime performance; do
  suite_path="$SCRIPT_DIR/$suite_dir"
  [ -d "$suite_path" ] || continue

  for test_script in "$suite_path"/test-*.sh "$suite_path"/benchmark-*.sh; do
    [ -f "$test_script" ] || continue
    suite_name="$(basename "$test_script" .sh)"

    echo ""
    echo "--- Running: $suite_dir/$suite_name ---"
    if bash "$test_script"; then
      echo "  Suite: PASSED"
    else
      echo "  Suite: FAILED"
      SUITES_FAIL=$((SUITES_FAIL+1))
    fi
    SUITES_RUN=$((SUITES_RUN+1))
  done
done

echo ""
echo "============================================"
echo "  Summary: $SUITES_RUN suites run, $SUITES_FAIL failed"
echo "============================================"

[ $SUITES_FAIL -eq 0 ] || exit 1
