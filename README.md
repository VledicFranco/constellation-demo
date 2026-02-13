# Constellation Demo

A reference project showcasing all [Constellation Engine](https://github.com/VledicFranco/constellation-engine) features in a realistic **Content Intelligence Platform** scenario.

Articles flow through NLP analysis, scoring, and routing — powered by built-in modules, two external providers (TypeScript + Scala), distributed caching, priority scheduling, and full observability.

## Quick Start

```bash
# One-time setup (builds TS SDK tarball for Docker)
./scripts/setup.sh        # Unix/macOS
.\scripts\setup.ps1       # Windows

# Start all 6 services
docker compose up --build

# Verify
curl http://localhost:8080/health
```

Once running:

| Service | URL |
|---------|-----|
| Dashboard | http://localhost:8080/dashboard |
| HTTP API | http://localhost:8080 |
| Grafana | http://localhost:3000 (admin / demo) |
| Prometheus | http://localhost:9091 |

## Architecture

```
                  ┌─────────────────┐
                  │   Grafana :3000  │──── Dashboards
                  └────────┬────────┘
                           │ scrape
                  ┌────────┴────────┐
                  │ Prometheus :9091 │──── Metrics collection
                  └────────┬────────┘
                           │ /metrics
┌──────────┐      ┌────────┴────────┐      ┌──────────────┐
│ provider  │─gRPC─│  constellation  │─gRPC─│  provider    │
│ ts :50051 │      │  server :8080   │      │  scala :50052│
└──────────┘      │  gRPC :9090     │      └──────────────┘
                  └────────┬────────┘
                           │
                  ┌────────┴────────┐
                  │ memcached :11211│
                  └─────────────────┘
```

6 Docker Compose services: custom Constellation server, TypeScript provider (sentiment analysis), Scala provider (entity extraction), Memcached, Prometheus, and Grafana.

## Feature Catalog

13 pipeline scripts (`pipelines/*.cst`) each demonstrate specific features:

| Pipeline | Features |
|----------|----------|
| `01-hello-world` | Input/output, module calls |
| `02-text-processing` | Trim, Uppercase, Lowercase, Replace, WordCount, Split |
| `03-data-aggregation` | SumList, Average, Max, Min, Filter, Range |
| `04-record-types` | Type system, stdlib, string operations |
| `05-guards-coalesce` | Guard (`when`), coalesce (`??`), optionals |
| `06-branch-logic` | Branch expressions, if/else, boolean ops |
| `07-module-options` | retry, timeout, cache, priority, backoff |
| `08-sentiment-analysis` | TS provider: AnalyzeSentiment, DetectLanguage, ExtractKeywords |
| `09-entity-extraction` | Scala provider: ExtractEntities, ClassifyTopic, ComputeReadability |
| `10-full-pipeline` | All providers combined into one pipeline |
| `11-resilience` | Retry + backoff, timeout, fallback, on_error |
| `12-caching-demo` | Cache TTLs (5min, 1h, 1d), memcached |
| `13-priority-scheduling` | critical, high, normal, low, background |

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, services, and data flow |
| [Features & Pipelines](docs/features.md) | Detailed feature catalog and pipeline reference |
| [CLI Operations](docs/cli-operations.md) | Constellation CLI command reference |
| [Observability](docs/observability.md) | Prometheus, Grafana, and metrics |
| [Providers](docs/providers.md) | External module provider reference |
| [Development](docs/development.md) | How to modify and extend the demo |

## Demo Scripts

```bash
./scripts/demo-run.sh       # Run all 13 pipelines with sample inputs
./scripts/demo-compile.sh   # Compile all pipelines
./scripts/demo-health.sh    # Health checks and metrics
./scripts/demo-deploy.sh    # Deploy workflow demo
```

## License

MIT
