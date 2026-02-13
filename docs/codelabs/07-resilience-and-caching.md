# Codelab 7: Resilience & Caching

**Duration:** ~25 minutes
**Difficulty:** Intermediate
**Prerequisites:** Demo running, completed Codelabs 1-4

## What You'll Learn

- Configure retry and timeout options on module calls
- Use backoff strategies for transient failures
- Enable caching to speed up repeated calls
- Combine resilience options for production-grade pipelines
- Observe cache hits and retries in metrics

## Step 1: Basic Retry

When a module call fails, retries can recover from transient errors. Create `pipelines/lab-retry.cst`:

```bash
cat > pipelines/lab-retry.cst << 'EOF'
# Retry Demo
# Retries the module call up to 3 times on failure

in text: String

result = Uppercase(text) with {
  retry: 3
}

out result
EOF
```

Run it:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-retry.cst | jq -Rs .),
    \"inputs\": {\"text\": \"hello world\"}
  }" | jq .outputs
```

The `retry: 3` option means: if the call fails, retry up to 3 additional times before giving up.

## Step 2: Timeout

Timeouts prevent slow modules from blocking the pipeline. Create `pipelines/lab-timeout.cst`:

```bash
cat > pipelines/lab-timeout.cst << 'EOF'
# Timeout Demo
# Each module call must complete within the specified duration

in text: String

# Fast operation — should always succeed
fast = Uppercase(text) with {
  timeout: 30s
}

# With both timeout and retry
resilient = Trim(text) with {
  timeout: 10s,
  retry: 2
}

out fast
out resilient
EOF
```

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-timeout.cst | jq -Rs .),
    \"inputs\": {\"text\": \"  hello world  \"}
  }" | jq .outputs
```

**Exercise:** Try setting `timeout: 0s` — what happens?

## Step 3: Backoff Strategies

When retrying, backoff prevents overwhelming a failing service. Create `pipelines/lab-backoff.cst`:

```bash
cat > pipelines/lab-backoff.cst << 'EOF'
# Backoff Demo
# Different backoff strategies for retries

use nlp.sentiment

in text: String

# Exponential backoff: 1s, 2s, 4s between retries
sentimentSafe = AnalyzeSentiment(text) with {
  retry: 3,
  backoff: exponential
}

# Fixed backoff: constant delay between retries
keywordsSafe = ExtractKeywords(text, 5) with {
  retry: 2,
  backoff: fixed
}

out sentimentSafe
out keywordsSafe
EOF
```

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-backoff.cst | jq -Rs .),
    \"inputs\": {\"text\": \"Machine learning is transforming the technology industry with amazing innovations.\"}
  }" | jq .outputs
```

Backoff options:
- `exponential` — Doubles the wait each retry (1s, 2s, 4s, 8s...)
- `fixed` — Same delay each retry

## Step 4: Caching

Caching stores module results so repeated calls with the same input skip execution. Create `pipelines/lab-cache.cst`:

```bash
cat > pipelines/lab-cache.cst << 'EOF'
# Caching Demo
# Cache results to avoid redundant computation

use nlp.sentiment
use nlp.entities

in article: String

# Cache sentiment for 5 minutes
sentiment = AnalyzeSentiment(article) with {
  cache: 5min
}

# Cache topic for 1 hour (rarely changes)
topic = ClassifyTopic(article) with {
  cache: 1h
}

# No cache — always fresh
readability = ComputeReadability(article)

out sentiment
out topic
out readability
EOF
```

Run it twice with the same input:

```bash
# First call — all modules execute
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-cache.cst | jq -Rs .),
    \"inputs\": {\"article\": \"The quick brown fox jumps over the lazy dog. This sentence contains every letter of the alphabet.\"}
  }" | jq .outputs

# Second call — cached modules return instantly
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-cache.cst | jq -Rs .),
    \"inputs\": {\"article\": \"The quick brown fox jumps over the lazy dog. This sentence contains every letter of the alphabet.\"}
  }" | jq .outputs
```

**Exercise:** Check the cache hit rate in metrics:

```bash
curl -s http://localhost:8080/metrics | jq .cache
```

The `hitRate` should increase after the second call.

## Step 5: Error Handling with on_error

The `on_error` option controls what happens when a module fails. Create `pipelines/lab-error-handling.cst`:

```bash
cat > pipelines/lab-error-handling.cst << 'EOF'
# Error Handling Demo
# Different strategies for handling module failures

use nlp.sentiment

in text: String

# Skip on error — produces None instead of failing the pipeline
sentiment = AnalyzeSentiment(text) with {
  retry: 1,
  on_error: skip
}

# Always runs — no special handling
upper = Uppercase(text)

out sentiment
out upper
EOF
```

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-error-handling.cst | jq -Rs .),
    \"inputs\": {\"text\": \"Testing error handling!\"}
  }" | jq .outputs
```

With `on_error: skip`, if `AnalyzeSentiment` fails, the pipeline continues — `sentiment` becomes `None` and `upper` still executes.

## Step 6: Combined Resilience Pattern

Now combine all options for a production-grade pipeline. Create `pipelines/lab-resilient-pipeline.cst`:

```bash
cat > pipelines/lab-resilient-pipeline.cst << 'EOF'
# Production Resilience Pattern
# Combines retry, timeout, backoff, cache, and error handling

use nlp.sentiment
use nlp.entities

in article: String

# Critical path: retry with backoff, timeout, and cache
sentiment = AnalyzeSentiment(article) with {
  retry: 3,
  timeout: 10s,
  backoff: exponential,
  cache: 5min
}

# Important but not critical: skip on error
entities = ExtractEntities(article) with {
  retry: 2,
  timeout: 15s,
  on_error: skip,
  cache: 10min
}

# Best-effort enrichment
topic = ClassifyTopic(article) with {
  retry: 1,
  timeout: 5s,
  on_error: skip
}

# Always available — built-in modules are fast and reliable
wordCount = WordCount(article)
cleanText = Trim(article)

out sentiment
out entities
out topic
out wordCount
EOF
```

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-resilient-pipeline.cst | jq -Rs .),
    \"inputs\": {\"article\": \"Dr. Smith from Google presented groundbreaking research on artificial intelligence. The new deep learning model achieves remarkable accuracy.\"}" | jq .outputs
```

**Pattern summary:**

| Tier | Strategy | Example |
|------|----------|---------|
| Critical | retry + backoff + timeout + cache | Sentiment analysis |
| Important | retry + timeout + on_error: skip + cache | Entity extraction |
| Best-effort | low retry + short timeout + on_error: skip | Topic classification |
| Reliable | no options needed | Built-in modules |

## Step 7: Observe Resilience in Metrics

Check the server metrics to see resilience in action:

```bash
# Cache statistics
curl -s http://localhost:8080/metrics | jq .cache

# Overall execution stats
curl -s http://localhost:8080/metrics | jq .execution
```

If Grafana is running (http://localhost:3000), check the Pipeline Execution dashboard for:
- Cache hit rate over time
- Retry counts per module
- Execution latency distribution

## Step 8: Clean Up

```bash
rm -f pipelines/lab-retry.cst pipelines/lab-timeout.cst \
      pipelines/lab-backoff.cst pipelines/lab-cache.cst \
      pipelines/lab-error-handling.cst pipelines/lab-resilient-pipeline.cst
```

## Checkpoint

You now know how to:
- [x] Configure retry counts for transient failure recovery
- [x] Set timeouts to prevent slow modules from blocking
- [x] Choose backoff strategies (exponential vs fixed)
- [x] Enable caching with TTL for repeated calls
- [x] Use `on_error: skip` for non-critical modules
- [x] Combine options into production resilience patterns
- [x] Monitor cache and retry metrics

**Next:** [Codelab 8: Observability Deep Dive](08-observability-deep-dive.md)
