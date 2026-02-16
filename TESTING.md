# Testing Guide

## Prerequisites

- Docker and Docker Compose
- `curl` and `python3` command-line tools
- `jq` (optional, for readable JSON output)

## Quick Start

```bash
# Start services
docker compose up -d

# Wait for health
./tests/lib/wait-for-health.sh

# Run all tests
./tests/run-all.sh
```

## Test Categories

### Compilation Tests (`tests/compilation/`)
Verify that all pipeline `.cst` files compile without errors.

- `test-all-compile.sh` -- Compiles every pipeline in `pipelines/`
- `test-invalid-pipelines.sh` -- Verifies that intentionally broken pipelines produce errors

### Execution Tests (`tests/execution/`)
Execute pipelines with sample inputs and compare to golden outputs.

- `test-all-execute.sh` -- Runs each pipeline and compares to `tests/golden/`
- Input files in `tests/inputs/` provide sample data

### Error Scenario Tests (`tests/errors/`)
Verify the server handles errors gracefully.

- `test-missing-inputs.sh` -- Submit pipelines without required inputs
- `test-type-mismatches.sh` -- Submit wrong input types
- `test-invalid-pipeline.sh` -- Reference non-existent modules

### Provider Tests (`tests/provider/`)
Verify external module providers (TypeScript and Scala).

- `test-registration.sh` -- Check that provider modules appear in `/modules`
- `test-health.sh` -- Verify all Docker services are healthy

### Runtime Tests (`tests/runtime/`)
Test runtime features like caching, retry, and timeout.

- `test-cache.sh` -- Verify cache hits on repeated execution
- `test-retry.sh` -- Test retry behavior with flaky modules
- `test-timeout.sh` -- Test timeout option handling

### Performance Benchmarks (`tests/performance/`)
Measure pipeline latency and cache effectiveness.

- `benchmark-pipelines.sh` -- Per-pipeline latency measurements
- `benchmark-cache.sh` -- Cache hit ratio benchmarks

## Golden Output Management

Golden outputs are stored in `tests/golden/`. On first run, the execution
test will create golden files automatically. Subsequent runs compare against
these baselines.

To regenerate golden outputs:
```bash
rm tests/golden/*.json
./tests/execution/test-all-execute.sh
```

## Demo Scripts

Interactive demo scripts in `demos/` showcase specific features:

- `demos/suspension/run.sh` -- Guard/coalesce behavior
- `demos/versioning/version-lifecycle.sh` -- Module listing and health
- `demos/canary/canary-rollout.sh` -- Consistency testing
- `demos/auth/auth-demo.sh` -- API endpoint access patterns

## CI/CD

Tests run automatically via `.github/workflows/demo-tests.yml` on push
and pull requests to master.
