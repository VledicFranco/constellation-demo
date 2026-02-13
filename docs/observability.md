# Observability

The demo includes a full observability stack: Prometheus for metrics collection and Grafana for visualization.

## Accessing Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | Anonymous access enabled, or admin / demo |
| Prometheus | http://localhost:9091 | No auth |
| Raw Metrics | http://localhost:8080/metrics | No auth |

## Grafana Dashboards

Three pre-provisioned dashboards are available under the "Constellation" folder:

### Overview

**UID:** `constellation-overview`

- **Server Status** — up/down indicator
- **Total Requests** — HTTP request counter
- **Cache Hit Rate** — ratio of cache hits to total lookups
- **Registered Modules** — total module count (built-in + external)
- **Scheduler Active Tasks** — time series of active vs queued tasks
- **Cache Hits vs Misses** — time series of cache performance

### Pipeline Execution

**UID:** `constellation-pipelines`

- **Execution Latency** — p50, p95, p99 percentiles
- **Throughput** — executions per second
- **Pipeline Errors** — error rate over time
- **Compilations** — compilation rate and cache hit rate

### Provider Health

**UID:** `constellation-providers`

- **Connected Providers** — count of active provider connections
- **External Modules** — count of registered external modules
- **Provider Heartbeats** — heartbeat rate (health indicator)
- **External Module Latency** — p50, p95 execution latency
- **Provider Errors** — error and reconnect rates

## Prometheus Configuration

Prometheus scrapes the constellation server every 15 seconds:

```yaml
# monitoring/prometheus/prometheus.yml
scrape_configs:
  - job_name: constellation
    metrics_path: /metrics
    static_configs:
      - targets: ["constellation-server:8080"]
```

## Querying Metrics

### Via curl

```bash
# JSON metrics from the server
curl http://localhost:8080/metrics | jq .

# Cache stats
curl http://localhost:8080/metrics | jq '.cache'

# Scheduler stats
curl http://localhost:8080/metrics | jq '.scheduler'
```

### Via Prometheus API

```bash
# Server up status
curl 'http://localhost:9091/api/v1/query?query=up{job="constellation"}'

# All constellation metrics
curl 'http://localhost:9091/api/v1/label/__name__/values' | jq '.data[] | select(startswith("constellation"))'
```

## Health Endpoints

| Endpoint | Auth Required | Description |
|----------|---------------|-------------|
| `GET /health` | No | Basic health status |
| `GET /health/live` | No | Liveness probe (always 200 if server is up) |
| `GET /health/ready` | No | Readiness probe (200 when fully initialized) |
| `GET /health/detail` | Depends | Detailed diagnostics (enabled in demo) |
| `GET /metrics` | No | JSON metrics for Prometheus |

### Health Check Script

```bash
./scripts/demo-health.sh
```

This script checks all health endpoints, displays metrics, and lists registered modules and pipelines.

## Customizing Dashboards

Grafana dashboards are stored as JSON in `monitoring/grafana/dashboards/`. To modify:

1. Edit the JSON file (or use Grafana's UI and export)
2. Place the updated JSON in `monitoring/grafana/dashboards/`
3. Grafana auto-reloads dashboards every 30 seconds

Dashboard provisioning is configured in `monitoring/grafana/provisioning/dashboards/dashboard.yml`.
