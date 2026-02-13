# Codelab 4: Calling External Providers

**Duration:** ~20 minutes
**Difficulty:** Intermediate
**Prerequisites:** Demo running (all services including providers), completed Codelabs 1-3

## What You'll Learn

- How external module providers work
- Call TypeScript provider modules (sentiment analysis)
- Call Scala provider modules (entity extraction)
- Combine built-in and external modules in one pipeline
- Understand namespaces and module resolution

## Step 1: Verify Providers Are Connected

First, check that both providers are registered:

```bash
curl -s http://localhost:8080/modules | jq '.[].name' | sort
```

You should see modules from three sources:
- **Built-in** (no prefix): `Uppercase`, `Trim`, `SumList`, etc.
- **TS provider** (`nlp.sentiment.*`): `nlp.sentiment.AnalyzeSentiment`, `nlp.sentiment.DetectLanguage`, `nlp.sentiment.ExtractKeywords`
- **Scala provider** (`nlp.entities.*`): `nlp.entities.ExtractEntities`, `nlp.entities.ClassifyTopic`, `nlp.entities.ComputeReadability`

If the `nlp.*` modules are missing, check the provider logs:

```bash
docker compose logs provider-ts
docker compose logs provider-scala
```

## Step 2: Analyze Sentiment (TypeScript Provider)

The `nlp.sentiment` namespace provides text sentiment analysis. Create `pipelines/lab-sentiment.cst`:

```bash
cat > pipelines/lab-sentiment.cst << 'EOF'
# Sentiment Analysis Lab
# Uses the TypeScript provider

use nlp.sentiment

in text: String

# Analyze sentiment: returns { score: Float, label: String }
sentiment = AnalyzeSentiment(text)

# Detect language: returns { language: String, confidence: Float }
language = DetectLanguage(text)

out sentiment
out language
EOF
```

Test with positive text:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-sentiment.cst | jq -Rs .),
    \"inputs\": {\"text\": \"This is absolutely wonderful and amazing! I love it!\"}
  }" | jq .outputs
```

**Expected:** `score` > 0, `label: "positive"`

Now test with negative text:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-sentiment.cst | jq -Rs .),
    \"inputs\": {\"text\": \"This is terrible and awful. I hate the disappointing results.\"}
  }" | jq .outputs
```

**Expected:** `score` < 0, `label: "negative"`

**Exercise:** Can you craft a perfectly neutral sentence (label: "neutral")?

## Step 3: Extract Keywords (TypeScript Provider)

```bash
cat > pipelines/lab-keywords.cst << 'EOF'
use nlp.sentiment

in article: String
in topN: Int

keywords = ExtractKeywords(article, topN)

out keywords
EOF
```

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-keywords.cst | jq -Rs .),
    \"inputs\": {
      \"article\": \"Machine learning algorithms are transforming software development. Deep learning models and neural networks enable new artificial intelligence applications.\",
      \"topN\": 5
    }
  }" | jq .outputs
```

**Exercise:** Try with `topN: 3` vs `topN: 10` — how does the output change?

## Step 4: Classify Topics (Scala Provider)

The `nlp.entities` namespace provides entity and topic analysis. Create `pipelines/lab-topics.cst`:

```bash
cat > pipelines/lab-topics.cst << 'EOF'
use nlp.entities

in text: String

# Classify topic: returns { topic: String, confidence: Float }
topic = ClassifyTopic(text)

# Compute readability: returns { score: Float, grade: String }
readability = ComputeReadability(text)

out topic
out readability
EOF
```

Test with different topics:

```bash
# Technology article
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-topics.cst | jq -Rs .),
    \"inputs\": {\"text\": \"The new software update includes machine learning algorithms for cloud computing. The API server handles data processing efficiently.\"}
  }" | jq .outputs

# Sports article
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-topics.cst | jq -Rs .),
    \"inputs\": {\"text\": \"The championship game was decided in the final season match. The team scored three goals to win the tournament.\"}
  }" | jq .outputs
```

**Exercise:** Write an article that gets classified as "health" or "science".

## Step 5: Combine Everything

Now build a full content analysis pipeline that uses both providers and built-in modules. Create `pipelines/lab-full-analysis.cst`:

```bash
cat > pipelines/lab-full-analysis.cst << 'EOF'
# Full Content Analysis Pipeline
# Combines built-in modules with both external providers

use nlp.sentiment
use nlp.entities

in article: String

# Step 1: Built-in text preprocessing
cleaned = Trim(article)
wordCount = WordCount(cleaned)
textLength = TextLength(cleaned)

# Step 2: TypeScript provider — sentiment & keywords
sentiment = AnalyzeSentiment(cleaned)
language = DetectLanguage(cleaned)
keywords = ExtractKeywords(cleaned, 5)

# Step 3: Scala provider — entities, topic, readability
entities = ExtractEntities(cleaned)
topic = ClassifyTopic(cleaned)
readability = ComputeReadability(cleaned)

out wordCount
out sentiment
out language
out keywords
out topic
out readability
EOF
```

Run the full pipeline:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-full-analysis.cst | jq -Rs .),
    \"inputs\": {\"article\": \"Dr. Smith from Google Inc presented wonderful new research on machine learning in New York. The breakthrough technology will transform the software industry.\"}
  }" | jq .outputs
```

You should see outputs from all three sources — built-in, TypeScript, and Scala.

## Step 6: Understand Namespace Resolution

When you write `use nlp.sentiment` and then call `AnalyzeSentiment(text)`, the compiler resolves this as `nlp.sentiment.AnalyzeSentiment`.

You can also use fully qualified names without `use`:

```constellation
# These are equivalent:
use nlp.sentiment
result = AnalyzeSentiment(text)

# vs
result = nlp.sentiment.AnalyzeSentiment(text)
```

**Exercise:** Modify `lab-full-analysis.cst` to use fully qualified names instead of `use` imports. Verify it produces the same output.

## Step 7: Clean Up

```bash
rm -f pipelines/lab-sentiment.cst pipelines/lab-keywords.cst \
      pipelines/lab-topics.cst pipelines/lab-full-analysis.cst
```

## Checkpoint

You now know how to:
- [x] Verify which external providers are connected
- [x] Call TypeScript provider modules via `use nlp.sentiment`
- [x] Call Scala provider modules via `use nlp.entities`
- [x] Combine built-in and external modules in one pipeline
- [x] Use fully qualified vs imported module names

**Next:** [Codelab 5: Adding a TypeScript Module](05-adding-a-typescript-module.md)
