#!/usr/bin/env bash
# Benchmark pipeline execution latencies
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# Pipelines that require external providers
PROVIDER_PIPELINES="08-sentiment-analysis 09-entity-extraction 10-full-pipeline"

# Pipelines that require example-app modules
BUILTIN_PIPELINES="01-hello-world 02-text-processing 03-data-aggregation 04-record-types 05-guards-coalesce 07-module-options 11-resilience 12-caching-demo 13-priority-scheduling"

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

  # Skip provider and builtin pipelines
  is_skip=false
  for pp in $PROVIDER_PIPELINES $BUILTIN_PIPELINES; do
    if [ "$name" = "$pp" ]; then
      is_skip=true
      break
    fi
  done
  if $is_skip; then
    echo "  SKIP: $name (requires non-stdlib modules)"
    continue
  fi

  # Build request using sys.argv for Windows compatibility
  request=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    source = f.read()
with open(sys.argv[2]) as f:
    inputs = json.load(f)
print(json.dumps({'source': source, 'inputs': inputs}))
" "$pipeline" "$input_file" 2>/dev/null || echo "ERROR")

  if [ "$request" = "ERROR" ]; then
    echo "  SKIP: $name (could not build request)"
    continue
  fi

  # Warmup run
  curl -s -X POST "$BASE_URL/run" \
    -H "Content-Type: application/json" \
    -d "$request" > /dev/null 2>&1

  # Timed runs (3 iterations)
  latencies=""
  for i in 1 2 3; do
    start_ms=$(python3 -c "import time; print(int(time.time()*1000))")

    result=$(curl -s -X POST "$BASE_URL/run" \
      -H "Content-Type: application/json" \
      -d "$request")

    end_ms=$(python3 -c "import time; print(int(time.time()*1000))")

    elapsed=$((end_ms - start_ms))
    if [ -z "$latencies" ]; then
      latencies="$elapsed"
    else
      latencies="$latencies,$elapsed"
    fi
  done

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
from datetime import datetime, timezone
data = json.load(sys.stdin)
output = {
    'timestamp': datetime.now(timezone.utc).isoformat(),
    'type': 'pipeline-execution',
    'pipelines': data
}
print(json.dumps(output, indent=2))
" > "$RESULTS_DIR/execution-latencies.json"

echo ""
echo "Results written to $RESULTS_DIR/execution-latencies.json"
