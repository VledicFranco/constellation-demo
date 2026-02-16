#!/usr/bin/env bash
# Benchmark cache hit ratio and performance improvement
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8080}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

echo "=== Cache Performance Benchmark ==="

# Use caching demo pipeline
pipeline="$REPO_DIR/pipelines/12-caching-demo.cst"
if [ ! -f "$pipeline" ]; then
  echo "SKIP: 12-caching-demo.cst not found"
  exit 0
fi

request=$(python3 -c "
import json
source = open('$pipeline').read()
inputs = {'text': 'benchmark cache test input'}
print(json.dumps({'source': source, 'inputs': inputs}))
")

# Collect initial metrics
echo "--- Initial metrics ---"
initial_metrics=$(curl -s "$BASE_URL/metrics")
echo "$initial_metrics" | python3 -c "
import json, sys
try:
    m = json.load(sys.stdin)
    cache = m.get('cache', {})
    if cache:
        print(f'  Initial cache: {json.dumps(cache)}')
    else:
        print('  No cache metrics available')
except:
    print('  Could not parse metrics')
" 2>/dev/null

# Cold run (first execution)
echo "--- Cold run ---"
cold_start=$(python3 -c "import time; print(int(time.time()*1000))")
curl -s -X POST "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$request" > /dev/null
cold_end=$(python3 -c "import time; print(int(time.time()*1000))")
cold_ms=$((cold_end - cold_start))
echo "  Cold execution: ${cold_ms}ms"

# Warm runs (should hit cache)
echo "--- Warm runs (10 iterations) ---"
warm_latencies=""
for i in $(seq 1 10); do
  start=$(python3 -c "import time; print(int(time.time()*1000))")

  curl -s -X POST "$BASE_URL/run" \
    -H "Content-Type: application/json" \
    -d "$request" > /dev/null

  end=$(python3 -c "import time; print(int(time.time()*1000))")
  elapsed=$((end - start))

  if [ -z "$warm_latencies" ]; then
    warm_latencies="$elapsed"
  else
    warm_latencies="$warm_latencies,$elapsed"
  fi
  echo "  Run $i: ${elapsed}ms"
done

# Final metrics
echo "--- Final metrics ---"
final_metrics=$(curl -s "$BASE_URL/metrics")
echo "$final_metrics" | python3 -c "
import json, sys
try:
    m = json.load(sys.stdin)
    cache = m.get('cache', {})
    if cache:
        print(f'  Final cache: {json.dumps(cache)}')
    else:
        print('  No cache metrics available')
except:
    print('  Could not parse metrics')
" 2>/dev/null

# Compute stats
python3 -c "
import json
from datetime import datetime

warm = [$warm_latencies]
cold = $cold_ms

avg_warm = sum(warm) / len(warm) if warm else 0
min_warm = min(warm) if warm else 0
max_warm = max(warm) if warm else 0

speedup = cold / avg_warm if avg_warm > 0 else 0

print(f'')
print(f'Summary:')
print(f'  Cold execution:  {cold}ms')
print(f'  Warm average:    {avg_warm:.0f}ms')
print(f'  Warm min:        {min_warm}ms')
print(f'  Warm max:        {max_warm}ms')
print(f'  Cache speedup:   {speedup:.1f}x')

result = {
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'type': 'cache-benchmark',
    'cold_ms': cold,
    'warm_runs': warm,
    'warm_avg_ms': round(avg_warm),
    'warm_min_ms': min_warm,
    'warm_max_ms': max_warm,
    'speedup': round(speedup, 1)
}

with open('$RESULTS_DIR/cache-benchmark.json', 'w') as f:
    json.dump(result, f, indent=2)
    f.write('\n')
print(f'  Results written to results/cache-benchmark.json')
"

echo ""
echo "Benchmark complete"
