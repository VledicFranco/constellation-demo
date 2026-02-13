# Codelab 8: Observability Deep Dive

**Duration:** ~30 minutes
**Difficulty:** Intermediate
**Prerequisites:** Demo running (including Prometheus and Grafana), completed Codelabs 1-4

## What You'll Learn

- Query the Constellation metrics endpoint
- Explore Prometheus metrics and write PromQL queries
- Navigate pre-built Grafana dashboards
- Build a custom Grafana panel
- Use health endpoints for operational monitoring
- Correlate pipeline execution with metrics

## Step 1: Explore the Health Endpoints

Constellation exposes several health endpoints for operational monitoring.

**Basic health check:**

```bash
curl -s http://localhost:8080/health | jq .
```

Returns `{"status": "healthy"}` when the server is running.

**Liveness probe** (for container orchestrators):

```bash
curl -s http://localhost:8080/health/live | jq .
```

**Readiness probe** (is the server ready to accept requests?):

```bash
curl -s http://localhost:8080/health/ready | jq .
```

**Detailed diagnostics:**

```bash
curl -s http://localhost:8080/health/detail | jq .
```

This shows component-level health: cache backend, scheduler, connected providers, uptime.

**Exercise:** What's the difference between liveness and readiness? When would readiness fail but liveness succeed?

## Step 2: Query the Metrics Endpoint

The metrics endpoint provides a JSON snapshot of all server statistics:

```bash
curl -s http://localhost:8080/metrics | jq .
```

Explore the different sections:

```bash
# Cache statistics
curl -s http://localhost:8080/metrics | jq .cache

# Execution statistics
curl -s http://localhost:8080/metrics | jq .execution

# Scheduler statistics (if enabled)
curl -s http://localhost:8080/metrics | jq .scheduler

# Module registry
curl -s http://localhost:8080/metrics | jq .modules
```

**Exercise:** Run a pipeline a few times, then check how the execution metrics change:

```bash
# Run a pipeline 5 times
for i in 1 2 3 4 5; do
  curl -s -X POST http://localhost:8080/run \
    -H "Content-Type: application/json" \
    -d "{
      \"source\": \"in x: String\nupper = Uppercase(x)\nout upper\",
      \"inputs\": {\"x\": \"test $i\"}
    }" > /dev/null
done

# Check updated metrics
curl -s http://localhost:8080/metrics | jq .execution
```

## Step 3: Prometheus Metrics Format

Constellation also exposes metrics in Prometheus format at the same endpoint. Prometheus scrapes this automatically every 15 seconds.

Verify Prometheus is collecting data:

```bash
# Check Prometheus targets
curl -s http://localhost:9091/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, health, lastScrape}'
```

You should see a target for `constellation-server:8080` with `health: "up"`.

## Step 4: Write PromQL Queries

Open Prometheus at http://localhost:9091 and try these queries in the Expression browser:

**Total pipeline executions:**
```promql
constellation_pipeline_executions_total
```

**Execution rate (per minute):**
```promql
rate(constellation_pipeline_executions_total[5m]) * 60
```

**Cache hit rate:**
```promql
constellation_cache_hit_rate
```

**Average execution duration:**
```promql
constellation_pipeline_duration_seconds_avg
```

**Exercise:** Generate some load and watch the metrics change in real time:

```bash
# Generate load in the background
for i in $(seq 1 20); do
  curl -s -X POST http://localhost:8080/run \
    -H "Content-Type: application/json" \
    -d "{
      \"source\": \"in x: String\nupper = Uppercase(x)\nout upper\",
      \"inputs\": {\"x\": \"load test $i\"}
    }" > /dev/null
  sleep 1
done
```

While the load runs, refresh the Prometheus graph to see execution counts climb.

## Step 5: Explore Grafana Dashboards

Open Grafana at http://localhost:3000 (login: admin / demo).

Three pre-built dashboards are available:

### Overview Dashboard

Navigate to **Dashboards → Overview**. This shows:

- **Server Uptime** — How long the server has been running
- **Total Requests** — Pipeline execution count
- **Cache Hit Rate** — Percentage of cache hits (gauge)
- **Active Modules** — Number of registered modules (built-in + external)

### Pipeline Execution Dashboard

Navigate to **Dashboards → Pipeline Execution**. This shows:

- **Execution Rate** — Pipelines per minute over time
- **Latency Distribution** — P50, P95, P99 execution times
- **Error Rate** — Failed executions as a percentage
- **Throughput** — Successful executions per second

### Provider Health Dashboard

Navigate to **Dashboards → Provider Health**. This shows:

- **Connected Providers** — Number of external providers
- **Provider Module Count** — Modules registered per provider
- **Provider Latency** — Response time per provider (TS vs Scala)
- **Heartbeat Status** — Last successful heartbeat per provider

**Exercise:** Run pipelines that use different providers and watch the Provider Health dashboard update:

```bash
# TS provider pipeline
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"use nlp.sentiment\nin t: String\ns = AnalyzeSentiment(t)\nout s\",
    \"inputs\": {\"t\": \"This is wonderful!\"}
  }" > /dev/null

# Scala provider pipeline
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": \"use nlp.entities\nin t: String\ne = ExtractEntities(t)\nout e\",
    \"inputs\": {\"t\": \"Dr. Smith works at Google in New York.\"}
  }" > /dev/null
```

## Step 6: Build a Custom Grafana Panel

Let's create a custom panel that tracks cache effectiveness.

1. In Grafana, click **+** → **Dashboard** → **Add visualization**
2. Select the **Prometheus** datasource
3. In the query editor, enter:

```promql
constellation_cache_hit_rate
```

4. Set visualization type to **Gauge**
5. Configure thresholds:
   - Green: > 0.8 (good cache hit rate)
   - Yellow: 0.5 - 0.8 (moderate)
   - Red: < 0.5 (poor — consider increasing TTLs)
6. Set the panel title to "Cache Effectiveness"
7. Click **Apply**

**Exercise:** Add a second panel showing execution latency:

```promql
histogram_quantile(0.95, rate(constellation_pipeline_duration_seconds_bucket[5m]))
```

This shows the 95th percentile execution time.

## Step 7: Correlate Pipelines with Metrics

Run a pipeline with caching and observe the metrics impact:

```bash
# Create a cached pipeline
cat > pipelines/lab-observe-cache.cst << 'EOF'
use nlp.sentiment

in text: String

sentiment = AnalyzeSentiment(text) with {
  cache: 5min
}

out sentiment
EOF

# First call (cache miss)
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-observe-cache.cst | jq -Rs .),
    \"inputs\": {\"text\": \"Observability is incredibly useful for debugging.\"}
  }" | jq .outputs

# Check metrics — note the cache state
curl -s http://localhost:8080/metrics | jq .cache

# Second call (cache hit)
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-observe-cache.cst | jq -Rs .),
    \"inputs\": {\"text\": \"Observability is incredibly useful for debugging.\"}
  }" | jq .outputs

# Check metrics again — hit rate should increase
curl -s http://localhost:8080/metrics | jq .cache
```

**What to look for:**
- `hits` count increases on the second call
- `hitRate` goes up
- Execution time for the second call should be lower (cached result)

## Step 8: Module Inventory

Use the modules endpoint to see everything registered:

```bash
# List all module names
curl -s http://localhost:8080/modules | jq '.[].name' | sort

# Count modules by source
echo "Built-in modules:"
curl -s http://localhost:8080/modules | jq '[.[] | select(.name | startswith("nlp") | not)] | length'

echo "TS provider modules:"
curl -s http://localhost:8080/modules | jq '[.[] | select(.name | startswith("nlp.sentiment"))] | length'

echo "Scala provider modules:"
curl -s http://localhost:8080/modules | jq '[.[] | select(.name | startswith("nlp.entities"))] | length'
```

## Step 9: Clean Up

```bash
rm -f pipelines/lab-observe-cache.cst
```

## Checkpoint

You now know how to:
- [x] Query health endpoints (health, live, ready, detail)
- [x] Read the JSON metrics endpoint
- [x] Verify Prometheus is scraping the server
- [x] Write PromQL queries for execution rate, cache hits, and latency
- [x] Navigate the three pre-built Grafana dashboards
- [x] Build a custom Grafana panel with thresholds
- [x] Correlate pipeline execution with cache metrics
- [x] Inventory registered modules by source

## Further Reading

- [Observability Guide](../observability.md) — Full reference for all metrics and dashboards
- [Architecture](../architecture.md) — How the monitoring stack fits together
- [Resilience & Caching](07-resilience-and-caching.md) — Configure the options that drive these metrics
