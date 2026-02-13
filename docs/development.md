# Development Guide

## Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for local TS provider development)
- JDK 17 + sbt (for local Scala development)
- `jq` (for demo scripts)

## Project Structure

```
constellation-demo/
  docker-compose.yml          # All 6 services
  .env                        # Default environment variables

  server/                     # Custom Constellation server
    build.sbt
    src/main/scala/demo/DemoServer.scala
    Dockerfile

  provider-ts/                # TypeScript NLP modules
    package.json
    src/index.ts
    src/modules/*.ts
    Dockerfile

  provider-scala/             # Scala NLP modules
    build.sbt
    src/main/scala/demo/provider/
    Dockerfile

  pipelines/                  # 13 .cst pipeline scripts
    01-hello-world.cst
    ...

  monitoring/                 # Prometheus + Grafana configs
    prometheus/prometheus.yml
    grafana/

  scripts/                    # Setup and demo scripts
  docs/                       # Documentation
```

## Setup

### First-Time Setup

```bash
# Unix/macOS
./scripts/setup.sh

# Windows
.\scripts\setup.ps1
```

This:
1. Builds the TS SDK tarball (`npm pack`) for Docker builds
2. Installs `provider-ts` dependencies
3. Verifies Docker is available

### Starting Services

```bash
# All services
docker compose up --build

# Individual service
docker compose up --build constellation-server

# Detached mode
docker compose up -d --build
```

## Modifying the Server

**Source:** `server/src/main/scala/demo/DemoServer.scala`

The server uses published Maven artifacts (`io.github.vledicfranco` v0.7.0). To change the server:

1. Edit `DemoServer.scala`
2. Rebuild: `docker compose up --build constellation-server`

### Adding Server Features

To enable auth:

```scala
import io.constellation.http.{AuthConfig, HashedApiKey, ApiRole}

// In the server builder:
.withAuth(AuthConfig(
  hashedKeys = List(HashedApiKey("your-api-key-here", ApiRole.Admin))
))
```

To enable rate limiting:

```scala
import io.constellation.http.RateLimitConfig

.withRateLimit(RateLimitConfig(requestsPerMinute = 100, burst = 20))
```

## Modifying Providers

### TypeScript Provider

```bash
cd provider-ts
npm install
npm run dev    # Build + run locally
```

To add a module:
1. Create `src/modules/my-module.ts`
2. Register in `src/index.ts`
3. Rebuild: `docker compose up --build provider-ts`

### Scala Provider

```bash
cd provider-scala
sbt run        # Run locally
```

To add a module:
1. Create `src/main/scala/demo/provider/modules/MyModule.scala`
2. Register in `Main.scala`
3. Rebuild: `docker compose up --build provider-scala`

## Adding Pipelines

1. Create a `.cst` file in `pipelines/`
2. The server auto-loads pipelines from the mounted volume (no restart needed)
3. Add sample inputs to `scripts/demo-run.sh` for the demo script
4. Test: `curl -X POST http://localhost:8080/run -H "Content-Type: application/json" -d '{"source": "...", "inputs": {...}}'`

## TS SDK Dependency

The TypeScript provider depends on the Constellation TS SDK. Two modes:

### Local Development

`package.json` uses `file:` to reference the SDK source directly:

```json
"@constellation-engine/provider-sdk": "file:../../constellation-engine/sdks/typescript"
```

Run `npm install` after any SDK changes.

### Docker Builds

`file:` references don't work in Docker (SDK is outside build context). The setup script creates a tarball:

```bash
cd ../constellation-engine/sdks/typescript && npm pack
# Copies .tgz into provider-ts/
```

The `Dockerfile` copies this tarball and runs `npm install` as normal.

## Troubleshooting

### Providers fail to connect

Providers need the constellation server to be running first. Docker Compose's `depends_on` handles startup order, but the gRPC server may not be ready immediately. Providers are configured with `restart: on-failure` to retry.

### Pipeline compilation errors

Check that the modules referenced in `.cst` files are registered. For built-in modules (Uppercase, Trim, etc.), the stdlib is always available. For external modules (nlp.sentiment.*, nlp.entities.*), the respective provider must be connected.

```bash
# List registered modules
curl http://localhost:8080/modules

# Check provider connections
curl http://localhost:8080/health/detail
```

### Cache not working

Verify memcached is running:

```bash
docker compose ps memcached
curl http://localhost:8080/metrics | jq '.cache'
```

### Grafana shows no data

1. Check Prometheus is scraping: http://localhost:9091/targets
2. Verify the constellation server is exposing metrics: `curl http://localhost:8080/metrics`
3. Wait 15-30 seconds for the first scrape cycle
