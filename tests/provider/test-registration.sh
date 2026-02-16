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

if [ -z "$modules" ] || echo "$modules" | grep -qi '"error"'; then
  echo "  FAIL: Could not retrieve module list"
  FAIL=$((FAIL+1))
else
  echo "  PASS: Retrieved module list"
  PASS=$((PASS+1))

  # Test 2: Check for stdlib modules (always registered)
  echo "--- Test: Stdlib modules present ---"
  for mod in stdlib.add stdlib.subtract stdlib.multiply stdlib.divide stdlib.trim stdlib.concat stdlib.identity stdlib.log; do
    if echo "$modules" | grep -q "\"$mod\""; then
      echo "  PASS: Found stdlib module: $mod"
      PASS=$((PASS+1))
    else
      echo "  FAIL: Missing stdlib module: $mod"
      FAIL=$((FAIL+1))
    fi
  done

  # Test 3: Check module count (should have at least 30 stdlib modules)
  echo "--- Test: Module count ---"
  count=$(echo "$modules" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(len(d.get('modules', [])))
except:
    print(0)
" 2>/dev/null || echo "0")
  if [ "$count" -ge 30 ]; then
    echo "  PASS: Module count $count (>= 30 expected)"
    PASS=$((PASS+1))
  else
    echo "  FAIL: Module count $count (expected >= 30)"
    FAIL=$((FAIL+1))
  fi

  # Test 4: Check for provider modules (may not be present if providers aren't connected)
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
