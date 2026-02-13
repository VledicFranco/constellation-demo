#!/usr/bin/env bash
set -euo pipefail

# Compile all pipeline scripts via the HTTP API
# Requires: constellation-server running on localhost:8080

SERVER="${CONSTELLATION_SERVER:-http://localhost:8080}"

echo "=== Compiling all pipelines ==="
echo "Server: $SERVER"
echo ""

for file in pipelines/*.cst; do
  name=$(basename "$file" .cst)
  echo -n "Compiling $name... "

  RESULT=$(curl -s -X POST "$SERVER/run" \
    -H "Content-Type: application/json" \
    -d "{\"source\": $(cat "$file" | jq -Rs .), \"inputs\": {}}" \
    -w "\n%{http_code}" 2>&1)

  HTTP_CODE=$(echo "$RESULT" | tail -1)
  BODY=$(echo "$RESULT" | head -n -1)

  if [ "$HTTP_CODE" = "200" ]; then
    echo "OK"
  else
    echo "FAILED (HTTP $HTTP_CODE)"
    echo "  $BODY" | head -3
  fi
done

echo ""
echo "=== Done ==="
