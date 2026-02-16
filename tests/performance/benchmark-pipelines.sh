#!/usr/bin/env bash
# Benchmark pipeline execution latencies
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# Provider pipelines to skip if not available
PROVIDER_PIPELINES="08-sentiment-analysis 09-entity-extraction 10-full-pipeline"

echo "=== Pipeline Execution Benchmarks ==="

# Collect results as JSON
results="{"
first=true

for input_file in "$REPO_DIR"/tests/inputs/*.json; do
  name=$(basename "$input_file" .json)
  pipeline="$REPO_DIR/pipelines/$name.cst"

  if [ ! -f "$pipeline" ]; then
    continue
  fi

  # Build request
  request=$(python3 -c "
import json
source = open('$pipeline').read()
inputs = json.load(open('$input_file'))
print(json.dumps({'source': source, 'inputs': inputs}))
" 2>/dev/null || echo "ERROR")

  if [ "$request" = "ERROR" ]; then
    continue
  fi

  # Warmup run
  curl -s -X POST "$BASE_URL/run" \
    -H "Content-Type: application/json" \
    -d "$request" > /dev/null 2>&1

  # Timed runs (3 iterations)
  latencies=""
  skip=false
  for i in 1 2 3; do
    start_ms=$(python3 -c "import time; print(int(time.time()*1000))")

    result=$(curl -s -X POST "$BASE_URL/run" \
      -H "Content-Type: application/json" \
      -d "$request")

    end_ms=$(python3 -c "import time; print(int(time.time()*1000))")

    # Check for errors (skip provider pipelines gracefully)
    if echo "$result" | grep -qi '"error"'; then
      is_provider=false
      for pp in $PROVIDER_PIPELINES; do
        if [ "$name" = "$pp" ]; then
          is_provider=true
          break
        fi
      done
      if $is_provider; then
        skip=true
        break
      fi
    fi

    elapsed=$((end_ms - start_ms))
    if [ -z "$latencies" ]; then
      latencies="$elapsed"
    else
      latencies="$latencies,$elapsed"
    fi
  done

  if $skip; then
    echo "  SKIP: $name (provider not connected)"
    continue
  fi

  # Calculate average
  avg=$(python3 -c "
lats = [$latencies]
print(int(sum(lats) / len(lats)))
" 2>/dev/null || echo "0")

  min_lat=$(python3 -c "print(min([$latencies]))" 2>/dev/null || echo "0")
  max_lat=$(python3 -c "print(max([$latencies]))" 2>/dev/null || echo "0")

  echo "  $name: avg=${avg}ms min=${min_lat}ms max=${max_lat}ms"

  if ! $first; then
    results="$results,"
  fi
  results="$results\"$name\":{\"avg_ms\":$avg,\"min_ms\":$min_lat,\"max_ms\":$max_lat,\"runs\":[$latencies]}"
  first=false
done

results="$results}"

# Write results
echo "$results" | python3 -c "
import json, sys
from datetime import datetime
data = json.load(sys.stdin)
output = {
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'type': 'pipeline-execution',
    'pipelines': data
}
print(json.dumps(output, indent=2))
" > "$RESULTS_DIR/execution-latencies.json"

echo ""
echo "Results written to $RESULTS_DIR/execution-latencies.json"
