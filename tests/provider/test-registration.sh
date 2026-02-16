#!/usr/bin/env bash
# Test provider module registration
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
PASS=0
FAIL=0
SKIP=0

echo "=== Provider Registration Tests ==="

# Test 1: Get module list
echo "--- Test: GET /modules ---"
modules=$(curl -s "$BASE_URL/modules")

if [ -z "$modules" ] || echo "$modules" | grep -qi "error"; then
  echo "  FAIL: Could not retrieve module list"
  FAIL=$((FAIL+1))
else
  echo "  PASS: Retrieved module list"
  PASS=$((PASS+1))

  # Test 2: Check for built-in modules
  echo "--- Test: Built-in modules present ---"
  for mod in Uppercase Lowercase Trim WordCount TextLength; do
    if echo "$modules" | grep -q "$mod"; then
      echo "  PASS: Found built-in module: $mod"
      PASS=$((PASS+1))
    else
      echo "  FAIL: Missing built-in module: $mod"
      FAIL=$((FAIL+1))
    fi
  done

  # Test 3: Check for provider modules (may not be present if providers aren't connected)
  echo "--- Test: Provider modules ---"

  # Check for TypeScript provider modules (nlp.sentiment namespace)
  if echo "$modules" | grep -qi "sentiment\|AnalyzeSentiment\|DetectLanguage\|ExtractKeywords"; then
    echo "  PASS: TypeScript provider modules found"
    PASS=$((PASS+1))
  else
    echo "  SKIP: TypeScript provider modules not found (provider may not be connected)"
    SKIP=$((SKIP+1))
  fi

  # Check for Scala provider modules (nlp.entities namespace)
  if echo "$modules" | grep -qi "entities\|ExtractEntities\|ClassifyTopic\|ComputeReadability"; then
    echo "  PASS: Scala provider modules found"
    PASS=$((PASS+1))
  else
    echo "  SKIP: Scala provider modules not found (provider may not be connected)"
    SKIP=$((SKIP+1))
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] || exit 1
