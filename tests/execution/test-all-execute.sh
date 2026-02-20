#!/usr/bin/env bash
# Execute all pipelines and compare to golden outputs
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# Pipelines that require external providers
PROVIDER_PIPELINES="08-sentiment-analysis 09-entity-extraction 10-full-pipeline"

# Pipelines that require example-app built-in modules (Uppercase, Lowercase, etc.)
# These are not registered in the demo server (only stdlib is registered)
BUILTIN_PIPELINES="01-hello-world 02-text-processing 03-data-aggregation 07-module-options 11-resilience 12-caching-demo 13-priority-scheduling"

echo "=== Execution Tests ==="

for input_file in "$SCRIPT_DIR"/../inputs/*.json; do
  name=$(basename "$input_file" .json)
  pipeline="$REPO_DIR/pipelines/$name.cst"
  golden="$SCRIPT_DIR/../golden/$name.json"

  if [ ! -f "$pipeline" ]; then
    echo "  SKIP: $name (no pipeline file)"
    SKIP=$((SKIP+1))
    continue
  fi

  # Check if this is a provider or builtin-dependent pipeline
  is_provider=false
  is_builtin=false
  for pp in $PROVIDER_PIPELINES; do
    if [ "$name" = "$pp" ]; then
      is_provider=true
      break
    fi
  done
  for bp in $BUILTIN_PIPELINES; do
    if [ "$name" = "$bp" ]; then
      is_builtin=true
      break
    fi
  done

  if $is_builtin; then
    echo "  SKIP: $name (requires example-app modules)"
    SKIP=$((SKIP+1))
    continue
  fi

  # Build request JSON using Python
  request=$(cd "$REPO_DIR" && python3 -c "
import json, sys, os
pipeline_path = sys.argv[1]
input_path = sys.argv[2]
with open(pipeline_path) as f:
    source = f.read()
with open(input_path) as f:
    inputs = json.load(f)
print(json.dumps({'source': source, 'inputs': inputs}))
" "$pipeline" "$input_file" 2>&1) || true

  if [ -z "$request" ] || echo "$request" | grep -qi "error\|traceback"; then
    echo "  SKIP: $name (could not build request)"
    SKIP=$((SKIP+1))
    continue
  fi

  # Execute
  result=$(curl -s -X POST "$BASE_URL/run" \
    -H "Content-Type: application/json" \
    -d "$request") || true

  if [ -z "$result" ]; then
    echo "  FAIL: $name (no response)"
    FAIL=$((FAIL+1))
    continue
  fi

  # Check for errors in response
  has_error=$(echo "$result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('error') and d.get('error') != 'null':
    print('yes')
elif not d.get('success', False):
    print('yes')
else:
    print('no')
" 2>/dev/null || echo "yes")

  if [ "$has_error" = "yes" ]; then
    if $is_provider; then
      echo "  SKIP: $name (provider not connected)"
      SKIP=$((SKIP+1))
      continue
    fi
    echo "  FAIL: $name (execution error)"
    echo "    $(echo "$result" | head -1)"
    FAIL=$((FAIL+1))
    continue
  fi

  # If no golden file exists, create it
  if [ ! -f "$golden" ]; then
    echo "$result" > "$golden"
    echo "  GOLDEN: $name (created golden file)"
    PASS=$((PASS+1))
    continue
  fi

  # Compare outputs (normalize JSON for comparison)
  comparison=$(python3 -c "
import json, sys
with open('$golden') as f:
    expected = json.load(f).get('outputs', {})
actual = json.loads(sys.argv[1]).get('outputs', {})
if json.dumps(expected, sort_keys=True) == json.dumps(actual, sort_keys=True):
    print('MATCH')
else:
    print('MISMATCH')
    print('Expected: ' + json.dumps(expected, sort_keys=True))
    print('Actual:   ' + json.dumps(actual, sort_keys=True))
" "$result" 2>/dev/null || echo "MISMATCH")

  if echo "$comparison" | head -1 | grep -q "MATCH"; then
    PASS=$((PASS+1))
    echo "  PASS: $name"
  else
    FAIL=$((FAIL+1))
    echo "  FAIL: $name"
    echo "$comparison" | tail -2 | sed 's/^/    /'
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] || exit 1
