#!/usr/bin/env bash
set -euo pipefail

# Demonstrates the deploy workflow: push, canary, promote, rollback
# Requires: constellation-server running on localhost:8080

SERVER="${CONSTELLATION_SERVER:-http://localhost:8080}"
PIPELINE_SOURCE=$(cat pipelines/01-hello-world.cst)

echo "=== Deploy Workflow Demo ==="
echo "Server: $SERVER"
echo ""

# Step 1: Compile the pipeline (creates a stored image)
echo "--- Step 1: Compile pipeline ---"
COMPILE_RESULT=$(curl -s -X POST "$SERVER/compile" \
  -H "Content-Type: application/json" \
  -d "{\"source\": $(echo "$PIPELINE_SOURCE" | jq -Rs .)}")
echo "$COMPILE_RESULT" | jq '{structuralHash: .structuralHash, inputSignature: .inputSignature}' 2>/dev/null || echo "$COMPILE_RESULT"
HASH=$(echo "$COMPILE_RESULT" | jq -r '.structuralHash // empty' 2>/dev/null || echo "")
echo ""

# Step 2: Execute by hash reference
if [ -n "$HASH" ]; then
  echo "--- Step 2: Execute by hash (sha256:$HASH) ---"
  EXEC_RESULT=$(curl -s -X POST "$SERVER/execute" \
    -H "Content-Type: application/json" \
    -d "{\"ref\": \"sha256:$HASH\", \"inputs\": {\"greeting\": \"Deploy test!\"}}")
  echo "$EXEC_RESULT" | jq '.outputs // .' 2>/dev/null || echo "$EXEC_RESULT"
  echo ""
fi

# Step 3: List stored pipelines
echo "--- Step 3: List pipelines ---"
curl -s "$SERVER/pipelines" | jq '.' 2>/dev/null || curl -s "$SERVER/pipelines"
echo ""

echo "=== Deploy workflow complete ==="
