#!/usr/bin/env bash
# Demonstrate guard/coalesce (suspension-like) behavior
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"

echo "=== Suspension Demo ==="

PIPELINE='use stdlib.compare\nin score: Int\nexcellent = "EXCELLENT" when gte(score, 90)\ngood = "GOOD" when gte(score, 70)\nresult = excellent ?? good ?? "NEEDS_WORK"\nout result'

echo "Test 1: High score (95) -> EXCELLENT"
curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "{\"source\":\"$PIPELINE\",\"inputs\":{\"score\":95}}"
echo ""

echo "Test 2: Medium score (75) -> GOOD"
curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "{\"source\":\"$PIPELINE\",\"inputs\":{\"score\":75}}"
echo ""

echo "Test 3: Low score (50) -> NEEDS_WORK"
curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "{\"source\":\"$PIPELINE\",\"inputs\":{\"score\":50}}"
echo ""
