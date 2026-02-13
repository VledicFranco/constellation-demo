#!/usr/bin/env bash
set -euo pipefail

# Run pipeline scripts with sample inputs via the HTTP API
# Requires: all services running (docker compose up)

SERVER="${CONSTELLATION_SERVER:-http://localhost:8080}"

run_pipeline() {
  local name="$1"
  local inputs="$2"
  local source

  echo "--- $name ---"
  source=$(cat "pipelines/${name}.cst")

  RESULT=$(curl -s -X POST "$SERVER/run" \
    -H "Content-Type: application/json" \
    -d "{\"source\": $(echo "$source" | jq -Rs .), \"inputs\": $inputs}")

  echo "$RESULT" | jq '.outputs // .error // .' 2>/dev/null || echo "$RESULT"
  echo ""
}

echo "=== Running demo pipelines ==="
echo "Server: $SERVER"
echo ""

# 01 — Hello World
run_pipeline "01-hello-world" '{"greeting": "Hello, Constellation!"}'

# 02 — Text Processing
run_pipeline "02-text-processing" '{"rawText": "  Hello World!  \nLine two  "}'

# 03 — Data Aggregation
run_pipeline "03-data-aggregation" '{"numbers": [10, 25, 3, 47, 8, 15], "threshold": 10}'

# 04 — Record Types
run_pipeline "04-record-types" '{"name": "Alice", "age": 30, "score": 85}'

# 05 — Guards and Coalesce
run_pipeline "05-guards-coalesce" '{"score": 92, "name": "Bob"}'

# 06 — Branch Logic
run_pipeline "06-branch-logic" '{"score": 85, "isUrgent": true}'

# 07 — Module Options
run_pipeline "07-module-options" '{"text": "Hello World", "query": "test"}'

# 08 — Sentiment Analysis (requires provider-ts)
run_pipeline "08-sentiment-analysis" '{"articleText": "This is a wonderful and amazing article about great technology!", "maxKeywords": 5}'

# 09 — Entity Extraction (requires provider-scala)
run_pipeline "09-entity-extraction" '{"articleText": "Dr. Smith from Google Inc presented his research in New York about machine learning algorithms."}'

# 10 — Full Pipeline (requires both providers)
run_pipeline "10-full-pipeline" '{"rawArticle": "Dr. Smith presented amazing research at Google Inc in New York. The breakthrough in machine learning technology is wonderful and will transform the software industry."}'

# 11 — Resilience
run_pipeline "11-resilience" '{"text": "Resilience test input"}'

# 12 — Caching Demo
run_pipeline "12-caching-demo" '{"text": "Cache this text for efficiency"}'

# 13 — Priority Scheduling
run_pipeline "13-priority-scheduling" '{"text": "Priority test"}'

echo "=== All pipelines executed ==="
