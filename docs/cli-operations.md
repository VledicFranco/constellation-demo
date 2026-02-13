# CLI Operations Guide

The Constellation CLI (`constellation`) is a command-line tool for compiling, running, deploying, and managing pipelines against a Constellation server.

## Installation

```bash
# Build the CLI JAR from the constellation-engine repo
cd ../constellation-engine
make cli-assembly

# The JAR is at modules/lang-cli/target/scala-3.3.4/constellation-lang-cli-assembly-*.jar
# Create an alias for convenience:
alias constellation='java -jar /path/to/constellation-lang-cli-assembly-0.7.0.jar'
```

## Configuration

### Config File

Location: `~/.constellation/config.json` (Unix) or `%USERPROFILE%\.constellation\config.json` (Windows)

```json
{
  "server": {
    "url": "http://localhost:8080",
    "token": "sk-your-api-key"
  },
  "defaults": {
    "output": "human",
    "viz_format": "dot"
  }
}
```

### Configuration Precedence

1. Command-line flags (`--server`, `--token`) — highest
2. Environment variables (`CONSTELLATION_SERVER_URL`, `CONSTELLATION_TOKEN`)
3. Config file (`~/.constellation/config.json`)
4. Built-in defaults — lowest

### Managing Config

```bash
# Show current configuration
constellation config show

# Set server URL
constellation config set server.url http://localhost:8080

# Set API token
constellation config set server.token sk-your-key

# Set default output format (human or json)
constellation config set defaults.output json

# Set default visualization format (dot, json, or mermaid)
constellation config set defaults.viz_format mermaid

# Get a specific config value
constellation config get server.url
```

## Global Flags

These flags apply to all commands:

| Flag | Short | Description |
|------|-------|-------------|
| `--server <url>` | `-s` | Server URL (overrides config) |
| `--token <token>` | `-t` | API authentication token |
| `--json` | `-j` | Output as JSON (machine-readable) |
| `--quiet` | `-q` | Suppress non-essential output |
| `--verbose` | `-v` | Verbose output with debug info |
| `--help` | `-h` | Show help for command |
| `--version` | `-V` | Show CLI version |

## Commands

### compile — Type-Check a Pipeline

Compiles a `.cst` file without executing it. Validates syntax, types, and module references.

```bash
constellation compile <file.cst>
```

**Examples:**

```bash
# Compile a pipeline
constellation compile pipelines/01-hello-world.cst

# Output:
# ✓ Compilation successful (hash: 7a3b8c9d...)

# Compile with JSON output
constellation compile pipelines/01-hello-world.cst --json

# Output:
# {"success": true, "structuralHash": "sha256:...", "name": "01-hello-world"}

# Compile against a remote server
constellation compile pipeline.cst --server https://prod.example.com --token sk-prod-key
```

**Error output:**

```
✗ Compilation failed with 2 error(s):
  • Syntax error at line 3: unexpected token '}'
  • Type error at line 7: expected Int, got String
```

**CI/CD validation (compile all pipelines):**

```bash
for f in pipelines/*.cst; do
  constellation compile "$f" --json || exit 1
done
```

---

### run — Execute a Pipeline

Compiles and executes a pipeline with provided inputs.

```bash
constellation run <file.cst> [--input key=value ...] [--input-file inputs.json]
```

| Option | Short | Description |
|--------|-------|-------------|
| `--input <key>=<value>` | `-i` | Provide an input value (repeatable) |
| `--input-file <path>` | `-f` | Load inputs from a JSON file |

**Input type inference:**

| Value | Inferred Type |
|-------|---------------|
| `"hello"` | String |
| `42` | Int |
| `3.14` | Float |
| `true` / `false` | Boolean |
| `[1,2,3]` | List (JSON) |
| `{"key":"val"}` | Record (JSON) |

**Examples:**

```bash
# Run with inline inputs
constellation run pipelines/01-hello-world.cst --input greeting="Hello!"

# Output:
# ✓ Execution completed:
#   upper: "HELLO!"

# Run with input file
constellation run pipelines/03-data-aggregation.cst --input-file inputs.json

# Mix file and inline inputs (inline overrides file)
constellation run pipeline.cst --input-file base.json --input override=true

# JSON output for scripting
RESULT=$(constellation run pipeline.cst -i x=5 --json | jq -r '.outputs.result')
```

**Input file format:**

```json
{
  "text": "Hello, World!",
  "count": 42,
  "enabled": true,
  "items": ["a", "b", "c"]
}
```

**Suspended execution (missing inputs):**

```
⏸ Execution suspended (ID: 550e8400-e29b-41d4-a716-446655440000)
  Missing inputs:
    email: String
    age: Int
```

---

### viz — Visualize Pipeline DAG

Generates a DAG visualization of a compiled pipeline.

```bash
constellation viz <file.cst> [--format FORMAT]
```

| Option | Short | Description |
|--------|-------|-------------|
| `--format <format>` | `-F` | Output format: `dot`, `json`, or `mermaid` (default: dot) |

**Examples:**

```bash
# Graphviz DOT format (default)
constellation viz pipelines/01-hello-world.cst

# Output:
# digraph pipeline {
#   rankdir=LR;
#   "input_greeting" -> "module_Uppercase";
#   "module_Uppercase" -> "output_upper";
# }

# Mermaid format (for GitHub/Markdown)
constellation viz pipelines/01-hello-world.cst --format mermaid

# Output:
# graph LR
#   input_greeting[greeting: String] --> module_Uppercase[Uppercase]
#   module_Uppercase --> output_upper[out: upper]

# JSON format
constellation viz pipelines/01-hello-world.cst --format json

# Render with Graphviz
constellation viz pipeline.cst | dot -Tpng -o pipeline.png
```

---

### server — Server Operations

Subcommands for monitoring and managing a running server.

#### server health

```bash
constellation server health
```

Checks server health. Exit code 0 = healthy, 2 = unhealthy, 3 = cannot connect.

```
✓ Server healthy
  Version: 0.7.0
  Uptime: 3d 14h 22m
  Pipelines: 12 loaded
```

#### server metrics

```bash
constellation server metrics
```

Displays server metrics: uptime, request count, cache stats, scheduler state.

```
Server Metrics

Server:
  Uptime: 3d 14h 22m
  Requests: 45023

Cache:
  Hits: 12500
  Misses: 800
  Hit Rate: 94.0%
  Entries: 42

Scheduler: enabled
  Active: 3
  Queued: 1
  Completed: 8923
```

#### server pipelines

```bash
# List all stored pipelines
constellation server pipelines

# Show pipeline details
constellation server pipelines show <name-or-hash>
```

**List output:**

```
3 pipeline(s) loaded:
  my-pipeline (7a3b8c9d...) - 5 modules, outputs: [result, count]
  data-processor (abc12345...) - 3 modules, outputs: [data]
```

**Detail output:**

```
Pipeline Details

  Hash: sha256:a1b2c3d4e5f6...
  Aliases: my-pipeline
  Compiled: 2026-02-09T10:30:45Z

Inputs:
  name: String
  age: Int

Outputs:
  greeting: String
  isAdult: Boolean

Modules: (3)
  Uppercase v1.0
  Trim v1.0
  WordCount v1.0
```

#### server executions

```bash
# List suspended executions
constellation server executions list [--limit N]

# Show execution details
constellation server executions show <id>

# Delete a suspended execution
constellation server executions delete <id>
```

---

### deploy — Pipeline Deployment

Deployment commands with versioning and canary releases.

#### deploy push

Deploy a pipeline to the server.

```bash
constellation deploy push <file.cst> [--name NAME]
```

| Option | Short | Description |
|--------|-------|-------------|
| `--name <name>` | `-n` | Pipeline name (default: filename without .cst) |

```bash
constellation deploy push pipelines/10-full-pipeline.cst --name content-analysis

# Output (new):
# ✓ Deployed content-analysis v1
#   Hash: abc123def456...

# Output (unchanged):
# ○ No changes to content-analysis (already at v1)
```

#### deploy canary

Start a canary deployment — gradually shift traffic to a new version.

```bash
constellation deploy canary <file.cst> [--name NAME] [--percent N]
```

| Option | Short | Description |
|--------|-------|-------------|
| `--name <name>` | `-n` | Pipeline name |
| `--percent <N>` | `-p` | Initial traffic percentage to new version (default: 10) |

```bash
constellation deploy canary pipelines/10-full-pipeline.cst --name content-analysis --percent 10

# Output:
# ✓ Canary started for content-analysis
#   New version: v2 (def456...)
#   Old version: v1 (abc123...)
#   Traffic: 10% to new version
```

#### deploy promote

Incrementally increase canary traffic (10% → 25% → 50% → 100%).

```bash
constellation deploy promote <pipeline>
```

```bash
constellation deploy promote content-analysis

# Output (partial):
# ✓ Canary content-analysis promoted: 10% → 25%

# Output (complete):
# ✓ Canary content-analysis promoted: 50% → 100% (complete)
```

#### deploy rollback

Roll back to a previous pipeline version.

```bash
constellation deploy rollback <pipeline> [--version N]
```

| Option | Short | Description |
|--------|-------|-------------|
| `--version <N>` | `-v` | Specific version to rollback to (default: previous) |

```bash
constellation deploy rollback content-analysis

# Output:
# ✓ Rolled back content-analysis
#   From: v3
#   To: v2
#   Hash: sha256:789abc...
```

#### deploy status

Check canary deployment status with metrics.

```bash
constellation deploy status <pipeline>
```

```
Canary Deployment: content-analysis

  Status: active
  Traffic: 25% to new version (step 2)
  Started: 2026-02-09T10:30:45Z

  Old version: v1 (sha256:a1b2c3...)
  New version: v2 (sha256:789abc...)

Metrics:
  Old version: 7500 reqs, 0.5% errors, 45ms p99
  New version: 2500 reqs, 0.3% errors, 42ms p99
```

---

## Exit Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | SUCCESS | Command succeeded |
| 1 | COMPILE_ERROR | Compilation failed (syntax/type errors) |
| 2 | RUNTIME_ERROR | Execution failed |
| 3 | CONNECTION_ERROR | Cannot connect to server |
| 4 | AUTH_ERROR | Authentication failed (invalid/missing token) |
| 5 | NOT_FOUND | Resource not found |
| 6 | CONFLICT | Resource conflict (e.g., canary already active) |
| 10 | USAGE_ERROR | Invalid arguments or file not found |

---

## Demo Workflows

### Compile All Pipelines

```bash
./scripts/demo-compile.sh
# or manually:
for f in pipelines/*.cst; do
  constellation compile "$f" || echo "FAILED: $f"
done
```

### Run All Pipelines

```bash
./scripts/demo-run.sh
# or manually:
constellation run pipelines/01-hello-world.cst -i greeting="Hello!"
constellation run pipelines/03-data-aggregation.cst -f inputs/data.json
```

### Health & Metrics

```bash
./scripts/demo-health.sh
# or manually:
constellation server health
constellation server metrics
constellation server pipelines
```

### Full Deploy Workflow

```bash
# 1. Push initial version
constellation deploy push pipelines/10-full-pipeline.cst --name content-analysis

# 2. Make changes to the pipeline, then canary deploy
constellation deploy canary pipelines/10-full-pipeline.cst --name content-analysis --percent 10

# 3. Monitor canary
constellation deploy status content-analysis

# 4. Promote if healthy
constellation deploy promote content-analysis
constellation deploy promote content-analysis  # repeat until 100%

# 5. Or rollback if issues detected
constellation deploy rollback content-analysis
```

### Scripting with JSON Output

```bash
# Get structural hash
HASH=$(constellation compile pipeline.cst --json | jq -r '.structuralHash')

# Extract specific output
RESULT=$(constellation run pipeline.cst -i text="hello" --json | jq -r '.outputs.upper')

# Check health in scripts
if constellation server health --quiet; then
  echo "Server is healthy"
else
  echo "Server is down" >&2
  exit 1
fi
```

## HTTP API Equivalents

The CLI communicates with the server via HTTP. You can use `curl` directly:

| CLI Command | HTTP Equivalent |
|-------------|-----------------|
| `constellation compile file.cst` | `POST /compile` |
| `constellation run file.cst` | `POST /run` |
| `constellation server health` | `GET /health` |
| `constellation server metrics` | `GET /metrics` |
| `constellation server pipelines` | `GET /pipelines` |
| `constellation deploy push` | `POST /pipelines/<name>/reload` |
| `constellation deploy canary` | `POST /pipelines/<name>/canary` |
| `constellation deploy promote` | `POST /pipelines/<name>/canary/promote` |
| `constellation deploy rollback` | `POST /pipelines/<name>/rollback` |
| `constellation deploy status` | `GET /pipelines/<name>/canary` |

**Example with curl:**

```bash
# Compile and run
curl -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d '{
    "source": "in greeting: String\nupper = Uppercase(greeting)\nout upper",
    "inputs": {"greeting": "Hello!"}
  }'

# With authentication
curl -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-your-api-key" \
  -d '{"source": "...", "inputs": {}}'
```
