# Constellation Demo

A reference project showcasing all [Constellation Engine](https://github.com/VledicFranco/constellation-engine) features in a realistic **Content Intelligence Platform** scenario.

Articles flow through NLP analysis, scoring, and routing — powered by built-in modules, two external providers (TypeScript + Scala), distributed caching, priority scheduling, and full observability.

## Prerequisites

Before running the demo, you need:

- **Docker & Docker Compose** v2.20+ — [install](https://docs.docker.com/get-docker/)
- **Git** — to clone this repository
- **curl** and **jq** — for running pipeline examples

Java, Scala, sbt, and Node.js are **not required** — they run inside Docker containers.

Additionally, you need a local clone of the [Constellation Engine](https://github.com/VledicFranco/constellation-engine) repository as a sibling directory (for the TS SDK tarball build):

```
parent-directory/
  constellation-engine/    # git clone https://github.com/VledicFranco/constellation-engine
  constellation-demo/      # this repo
```

## Quick Start

### 1. First-time setup

The TypeScript provider requires a compiled SDK tarball from the engine repo:

```bash
./scripts/setup.sh        # Unix/macOS
.\scripts\setup.ps1       # Windows
```

This script builds the TS SDK tarball via `npm pack`, copies it to `provider-ts/`, installs Node dependencies, and verifies Docker is available.

> **If you skip this step**, `docker compose up --build` will fail with:
> `COPY constellation-engine-provider-sdk-*.tgz ./` — no matching files found

### 2. Start all services

```bash
docker compose up --build
```

### 3. Verify

```bash
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

## Codelabs

Hands-on exercises to learn Constellation Engine by doing. Start with Codelab 1 and work your way through — each builds on skills from earlier labs.

| # | Codelab | Duration | What You'll Learn |
|---|---------|----------|-------------------|
| 1 | [Your First Pipeline](docs/codelabs/01-your-first-pipeline.md) | 15 min | Write, compile, and execute a pipeline from scratch |
| 2 | [Exploring the Dashboard](docs/codelabs/02-exploring-the-dashboard.md) | 15 min | Browse pipelines, run scripts, visualize DAGs in the web UI |
| 3 | [Building a Data Pipeline](docs/codelabs/03-building-a-data-pipeline.md) | 20 min | Combine text and data modules, use guards, branches, and stdlib |
| 4 | [Calling External Providers](docs/codelabs/04-calling-external-providers.md) | 20 min | Use the TS and Scala NLP providers in your pipelines |
| 5 | [Adding a TypeScript Module](docs/codelabs/05-adding-a-typescript-module.md) | 30 min | Build, register, and deploy a new module in the TS provider |
| 6 | [Adding a Scala Module](docs/codelabs/06-adding-a-scala-module.md) | 30 min | Build, register, and deploy a new module in the Scala provider |
| 7 | [Resilience & Caching](docs/codelabs/07-resilience-and-caching.md) | 25 min | Add retry, timeout, fallback, cache options and observe metrics |
| 8 | [Observability Deep Dive](docs/codelabs/08-observability-deep-dive.md) | 25 min | Query Prometheus, build Grafana panels, interpret metrics |

### Prerequisites

All codelabs assume the demo is running:

```bash
./scripts/setup.sh              # first time only
docker compose up --build -d    # start all services
curl http://localhost:8080/health  # verify
```

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
