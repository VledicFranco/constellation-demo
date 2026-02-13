# Architecture

## Overview

The Constellation Demo is a Content Intelligence Platform built on the Constellation Engine. Articles flow through NLP analysis, scoring, and routing using a combination of built-in modules and external providers.

## System Diagram

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

## Services

| Service | Image | Ports | Purpose |
|---------|-------|-------|---------|
| `constellation-server` | Custom (JVM 17) | 8080 (HTTP), 9090 (gRPC) | Core engine with all features |
| `provider-ts` | Custom (Node 20) | 50051 (gRPC) | TypeScript sentiment analysis modules |
| `provider-scala` | Custom (JVM 17) | 50052 (gRPC) | Scala entity extraction modules |
| `memcached` | `memcached:1.6-alpine` | 11211 | Distributed cache backend |
| `prometheus` | `prom/prometheus:latest` | 9091 | Metrics collection and alerting |
| `grafana` | `grafana/grafana:latest` | 3000 | Dashboards and visualization |

## Constellation Server

The custom server (`server/src/main/scala/demo/DemoServer.scala`) wires up all Constellation features:

1. **Priority Scheduler** — bounded scheduler with starvation protection, configured via `CONSTELLATION_SCHEDULER_*` env vars
2. **Memcached Cache** — distributed cache backend for module result caching
3. **StdLib Modules** — all built-in math, string, list, boolean, comparison, and conversion functions
4. **Module Provider Manager** — gRPC server (port 9090) that accepts external provider registrations
5. **Dashboard** — web UI for browsing pipelines, running scripts, and viewing DAGs
6. **Pipeline Loader** — auto-loads `.cst` files from the mounted `pipelines/` volume
7. **CORS** — wildcard CORS for Grafana integration
8. **Health Checks** — liveness, readiness, and detail endpoints

### Dependencies

All from Maven Central (`io.github.vledicfranco` v0.7.0):

```
constellation-runtime
constellation-lang-compiler
constellation-lang-stdlib
constellation-http-api
constellation-module-provider
constellation-cache-memcached
```

## Data Flow

1. Client sends a pipeline source (`.cst` file) or references a stored pipeline
2. Server compiles the pipeline via the lang-compiler
3. Server resolves module calls — built-in modules run locally, external modules dispatch via gRPC
4. External providers (TS/Scala) receive execution requests and return results
5. Results are cached in Memcached if `cache:` option is specified
6. Prometheus scrapes the `/metrics` endpoint every 15 seconds
7. Grafana visualizes metrics via pre-provisioned dashboards

## Provider Registration Flow

```
provider-ts                    constellation-server
    │                                │
    │── gRPC Register ──────────────>│  (namespace: nlp.sentiment)
    │   modules: [AnalyzeSentiment,  │
    │    DetectLanguage,             │
    │    ExtractKeywords]            │
    │<── RegisterResponse ──────────│
    │                                │
    │<── Heartbeat ─────────────────│  (periodic health checks)
    │── HeartbeatAck ──────────────>│
    │                                │
    │<── ExecuteRequest ────────────│  (when pipeline calls nlp.sentiment.*)
    │── ExecuteResponse ───────────>│
```

## Environment Variables

| Variable | Default | Service | Description |
|----------|---------|---------|-------------|
| `CONSTELLATION_PORT` | `8080` | server | HTTP API port |
| `CONSTELLATION_GRPC_PORT` | `9090` | server | gRPC provider port |
| `CONSTELLATION_SCHEDULER_ENABLED` | `true` | server | Enable bounded scheduler |
| `CONSTELLATION_SCHEDULER_MAX_CONCURRENCY` | `16` | server | Max concurrent tasks |
| `CONSTELLATION_CST_DIR` | `/app/pipelines` | server | Pipeline auto-load directory |
| `MEMCACHED_ADDRESS` | `memcached:11211` | server | Memcached connection |
| `CONSTELLATION_ADDRESS` | varies | providers | Server gRPC address |
| `EXECUTOR_PORT` | varies | providers | Provider executor port |
| `EXECUTOR_HOST` | varies | providers | Provider hostname (for callback) |
