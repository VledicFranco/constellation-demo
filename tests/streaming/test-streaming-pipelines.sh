#!/usr/bin/env bash
# Test streaming pipeline lifecycle: compile → deploy → verify status → stop
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0

echo "=== Streaming Pipeline Tests ==="

# Check if streaming API is available
stream_check=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/streams" 2>/dev/null || echo "000")
if [ "$stream_check" = "000" ] || [ "$stream_check" = "404" ]; then
  echo "  SKIP: Streaming API not available (HTTP $stream_check)"
  echo ""
  echo "Results: 0 passed, 0 failed, 0 skipped (streaming not enabled)"
  exit 0
fi

for pipeline in "$REPO_DIR"/pipelines/streaming/*.cst; do
  [ -f "$pipeline" ] || continue
  name=$(basename "$pipeline" .cst)

  # Step 1: Compile the pipeline to get a structural hash
  source_content=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
print(json.dumps({'source': source, 'name': sys.argv[2]}))
" "$pipeline" "$name" 2>&1) || true

  if [ -z "$source_content" ]; then
    echo "  FAIL: $name (could not read pipeline)"
    FAIL=$((FAIL+1))
    continue
  fi

  compile_result=$(curl -s -X POST "$BASE_URL/compile" \
    -H "Content-Type: application/json" \
    -d "$source_content")

  compile_success=$(echo "$compile_result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print('true' if d.get('success', False) else 'false')
except:
    print('false')
" 2>/dev/null || echo "false")

  if [ "$compile_success" != "true" ]; then
    echo "  FAIL: $name (compilation failed)"
    echo "    $compile_result" | head -3
    FAIL=$((FAIL+1))
    continue
  fi

  # Extract structural hash for deployment
  structural_hash=$(echo "$compile_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('structuralHash', ''))
" 2>/dev/null || echo "")

  if [ -z "$structural_hash" ]; then
    echo "  FAIL: $name (no structural hash returned)"
    FAIL=$((FAIL+1))
    continue
  fi

  # Step 2: Deploy as streaming pipeline
  deploy_request=$(python3 -c "
import json
req = {
    'pipelineRef': '$structural_hash',
    'name': '$name',
    'sourceBindings': {},
    'sinkBindings': {}
}
print(json.dumps(req))
")

  deploy_result=$(curl -s -X POST "$BASE_URL/api/v1/streams" \
    -H "Content-Type: application/json" \
    -d "$deploy_request" 2>/dev/null) || true

  deploy_status=$(echo "$deploy_result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    status = d.get('status', '')
    stream_id = d.get('id', '')
    print(f'{status}|{stream_id}')
except:
    print('error|')
" 2>/dev/null || echo "error|")

  status="${deploy_status%%|*}"
  stream_id="${deploy_status#*|}"

  if [ "$status" = "running" ] && [ -n "$stream_id" ]; then
    # Step 3: Verify the stream is listed
    list_result=$(curl -s "$BASE_URL/api/v1/streams/$stream_id" 2>/dev/null) || true
    list_status=$(echo "$list_result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

    # Step 4: Stop the stream
    stop_result=$(curl -s -X DELETE "$BASE_URL/api/v1/streams/$stream_id" 2>/dev/null) || true

    if [ "$list_status" = "running" ]; then
      PASS=$((PASS+1))
      echo "  PASS: $name (deployed, verified, stopped)"
    else
      FAIL=$((FAIL+1))
      echo "  FAIL: $name (deployed but status was '$list_status')"
    fi
  else
    # Deployment may fail if connectors are not configured — that's expected
    # Check if it's a connector validation error (expected) vs a real failure
    error_msg=$(echo "$deploy_result" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('error', 'unknown error'))
except:
    print('parse error')
" 2>/dev/null || echo "unknown")

    if echo "$error_msg" | grep -qi "connector\|binding\|source\|sink\|config"; then
      echo "  SKIP: $name (no connectors configured: $error_msg)"
      SKIP=$((SKIP+1))
    else
      echo "  FAIL: $name (deploy failed: $error_msg)"
      FAIL=$((FAIL+1))
    fi
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[ $FAIL -eq 0 ] || exit 1
