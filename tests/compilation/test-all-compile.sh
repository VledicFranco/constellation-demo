#!/usr/bin/env bash
# Test that all pipelines compile successfully
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0
ERRORS=""

# Pipelines that require external providers
PROVIDER_PIPELINES="08-sentiment-analysis 09-entity-extraction 10-full-pipeline"

# Pipelines that require example-app built-in modules (Uppercase, Lowercase, etc.)
BUILTIN_PIPELINES="01-hello-world 02-text-processing 03-data-aggregation 04-record-types 05-guards-coalesce 07-module-options 11-resilience 12-caching-demo 13-priority-scheduling"

echo "=== Compilation Tests ==="

for pipeline in "$REPO_DIR"/pipelines/*.cst; do
  name=$(basename "$pipeline" .cst)

  # Check if this is a builtin-dependent or provider pipeline
  is_skip=false
  for bp in $BUILTIN_PIPELINES; do
    if [ "$name" = "$bp" ]; then
      is_skip=true
      break
    fi
  done
  for pp in $PROVIDER_PIPELINES; do
    if [ "$name" = "$pp" ]; then
      is_skip=true
      break
    fi
  done

  if $is_skip; then
    echo "  SKIP: $name.cst (requires non-stdlib modules)"
    SKIP=$((SKIP+1))
    continue
  fi

  # Build JSON request using Python
  request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source}))
" "$pipeline" 2>&1) || true

  if [ -z "$request" ]; then
    FAIL=$((FAIL+1))
    echo "  FAIL: $name.cst (could not read pipeline)"
    continue
  fi

  result=$(curl -s -X POST "$BASE_URL/compile" \
    -H "Content-Type: application/json" \
    -d "$request")

  # Check for compilation success via JSON response
  success=$(echo "$result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

  if [ "$success" = "true" ]; then
    PASS=$((PASS+1))
    echo "  PASS: $name.cst"
  else
    FAIL=$((FAIL+1))
    ERRORS="$ERRORS\n  FAIL: $name.cst"
    echo "  FAIL: $name.cst"
    echo "    $result" | head -5
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
if [ $FAIL -gt 0 ]; then
  echo -e "Failures:$ERRORS"
  exit 1
fi
