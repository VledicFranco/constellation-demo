# Features & Pipeline Reference

## Pipeline Overview

Each `.cst` file in `pipelines/` demonstrates specific Constellation Engine features with inline comments explaining what's being showcased.

## Pipeline Details

### 01 — Hello World

**File:** `pipelines/01-hello-world.cst`
**Features:** Input declarations, module calls, output declarations

The simplest pipeline: takes a string, converts to uppercase, outputs the result.

```constellation
in greeting: String
upper = Uppercase(greeting)
out upper
```

**Sample Input:** `{"greeting": "Hello, Constellation!"}`

---

### 02 — Text Processing

**File:** `pipelines/02-text-processing.cst`
**Features:** Built-in text modules

Demonstrates chaining multiple text operations: Trim, Lowercase, Uppercase, Replace, WordCount, TextLength, Contains, Split, SplitLines.

**Sample Input:** `{"rawText": "  Hello World!  \nLine two  "}`

---

### 03 — Data Aggregation

**File:** `pipelines/03-data-aggregation.cst`
**Features:** Built-in data modules

Numeric list processing: SumList, Average, Max, Min, FilterGreaterThan, MultiplyEach, Range, FormatNumber.

**Sample Input:** `{"numbers": [10, 25, 3, 47, 8, 15], "threshold": 10}`

---

### 04 — Record Types

**File:** `pipelines/04-record-types.cst`
**Features:** Type system, stdlib functions, `use` imports

Shows stdlib namespace imports (`use stdlib.math`, `use stdlib.string`, `use stdlib.compare`) and calling functions like `string-length`, `gte`, `multiply`, `concat`, `to-string`.

**Sample Input:** `{"name": "Alice", "age": 30, "score": 85}`

---

### 05 — Guards and Coalesce

**File:** `pipelines/05-guards-coalesce.cst`
**Features:** Guard expressions (`when`), coalesce operator (`??`)

Guards produce `Optional<T>` — `Some(value)` when the condition is true, `None` when false. Coalesce (`??`) unwraps an Optional with a fallback.

```constellation
excellentMsg = "Excellent!" when gte(score, 90)
message = excellentMsg ?? "Keep trying!"
```

**Sample Input:** `{"score": 92, "name": "Bob"}`

---

### 06 — Branch Logic

**File:** `pipelines/06-branch-logic.cst`
**Features:** Branch expressions, if/else, boolean operators (`and`, `or`, `not`)

Multi-way conditionals with `branch { condition -> value, otherwise -> default }`.

```constellation
grade = branch {
  gte(score, 90) -> "A",
  gte(score, 80) -> "B",
  otherwise -> "F"
}
```

**Sample Input:** `{"score": 85, "isUrgent": true}`

---

### 07 — Module Options

**File:** `pipelines/07-module-options.cst`
**Features:** `retry`, `timeout`, `cache`, `priority`, `backoff`, `on_error`, combined options

Shows all execution options via the `with` clause:

```constellation
production = Uppercase(text) with
    retry: 3,
    timeout: 30s,
    cache: 5min,
    priority: high,
    backoff: exponential
```

**Sample Input:** `{"text": "Hello World", "query": "test"}`

---

### 08 — Sentiment Analysis (TypeScript Provider)

**File:** `pipelines/08-sentiment-analysis.cst`
**Features:** External modules from the `nlp.sentiment` namespace

Calls three modules from the TypeScript provider:
- `AnalyzeSentiment` — keyword-based sentiment scoring (-1.0 to 1.0)
- `DetectLanguage` — heuristic language detection
- `ExtractKeywords` — TF-based keyword extraction

**Sample Input:** `{"articleText": "This is a wonderful and amazing article about great technology!", "maxKeywords": 5}`

---

### 09 — Entity Extraction (Scala Provider)

**File:** `pipelines/09-entity-extraction.cst`
**Features:** External modules from the `nlp.entities` namespace

Calls three modules from the Scala provider:
- `ExtractEntities` — regex-based named entity recognition
- `ClassifyTopic` — keyword-based topic classification
- `ComputeReadability` — Flesch-Kincaid readability scoring

**Sample Input:** `{"articleText": "Dr. Smith from Google Inc presented his research in New York about machine learning algorithms."}`

---

### 10 — Full Pipeline

**File:** `pipelines/10-full-pipeline.cst`
**Features:** Combined pipeline using built-in + both external providers

The complete content intelligence pipeline:
1. Text preprocessing (built-in: Trim, WordCount, TextLength)
2. Sentiment analysis (TypeScript: AnalyzeSentiment, DetectLanguage, ExtractKeywords)
3. Entity & topic analysis (Scala: ExtractEntities, ClassifyTopic, ComputeReadability)

All external calls use `cache: 10min` for efficiency.

**Sample Input:** `{"rawArticle": "Dr. Smith presented amazing research at Google Inc in New York."}`

---

### 11 — Resilience Patterns

**File:** `pipelines/11-resilience.cst`
**Features:** Retry + exponential backoff, timeout, `on_error: skip`, `fallback`

Shows how to build fault-tolerant pipelines:
- `retry: 3, backoff: exponential` — retry with increasing delays
- `timeout: 5s` — fail fast on slow operations
- `on_error: skip` — produce `None` instead of failing
- `fallback: "value"` — use a default on error

---

### 12 — Caching Demo

**File:** `pipelines/12-caching-demo.cst`
**Features:** Cache TTLs with Memcached backend

Different cache durations for different use cases:
- `cache: 5min` — short-lived, frequently changing data
- `cache: 1h` — moderately stable data
- `cache: 1d` — stable reference data

View cache hit rates via `curl http://localhost:8080/metrics`.

---

### 13 — Priority Scheduling

**File:** `pipelines/13-priority-scheduling.cst`
**Features:** Priority levels for the bounded scheduler

When `CONSTELLATION_SCHEDULER_ENABLED=true`, modules execute by priority:
- `priority: critical` — executed immediately
- `priority: high` — runs before normal tasks
- `priority: normal` — default
- `priority: low` — yields to higher priority
- `priority: background` — runs when nothing else is queued
- `priority: 42` — custom numeric priority

Starvation protection boosts low-priority tasks after the configured timeout.
