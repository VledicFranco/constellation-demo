#!/usr/bin/env bash
# Demonstrate canary-style testing -- run same pipeline multiple times
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "=== Canary Rollout Demo ==="
echo "Running same pipeline 5 times to verify consistency..."

PIPELINE='use stdlib.compare\nin score: Int\ngrade = branch {\n  gte(score, 90) -> "A",\n  gte(score, 80) -> "B",\n  otherwise -> "C"\n}\nout grade'
PASS=0
FAIL=0

for i in $(seq 1 5); do
  RESULT=$(curl -s -X POST "$BASE_URL/run" \
    -H "Content-Type: application/json" \
    -d "{\"source\":\"$PIPELINE\",\"inputs\":{\"score\":85}}")

  if echo "$RESULT" | grep -q '"success":true'; then
    echo "  Run $i: PASS"
    PASS=$((PASS+1))
  else
    echo "  Run $i: FAIL"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed out of 5"
