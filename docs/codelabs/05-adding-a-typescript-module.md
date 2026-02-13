# Codelab 5: Adding a TypeScript Module

**Duration:** ~30 minutes
**Difficulty:** Advanced
**Prerequisites:** Demo running, completed Codelabs 1-4, basic TypeScript knowledge

## What You'll Learn

- Define a new module using the TypeScript Provider SDK
- Register it with the provider
- Rebuild and deploy the provider container
- Call the new module from a pipeline
- Remove a module from the provider

## Step 1: Plan Your Module

We'll build a `SummarizeText` module that produces a simple extractive summary — taking the first N sentences from a text.

| Property | Value |
|----------|-------|
| Name | `SummarizeText` |
| Namespace | `nlp.sentiment` (same as existing TS provider) |
| Input | `{ text: String, maxSentences: Int }` |
| Output | `{ summary: String, sentenceCount: Int }` |

## Step 2: Create the Module File

Create `provider-ts/src/modules/summarize-text.ts`:

```typescript
import {
  type ModuleDefinition,
  type CValue,
  CTypes,
  CValues,
} from "@constellation-engine/provider-sdk";

/**
 * SummarizeText — extractive text summarization.
 *
 * Takes a text and returns the first N sentences as a summary.
 */
export const summarizeTextModule: ModuleDefinition = {
  name: "SummarizeText",
  inputType: CTypes.product({
    text: CTypes.string(),
    maxSentences: CTypes.int(),
  }),
  outputType: CTypes.product({
    summary: CTypes.string(),
    sentenceCount: CTypes.int(),
  }),
  version: "1.0.0",
  description: "Extract first N sentences as a summary",
  handler: async (input: CValue): Promise<CValue> => {
    if (input.tag !== "CProduct") throw new Error("Expected CProduct input");

    const textVal = input.value["text"];
    const maxVal = input.value["maxSentences"];
    if (!textVal || textVal.tag !== "CString") throw new Error("Expected text: String");
    if (!maxVal || maxVal.tag !== "CInt") throw new Error("Expected maxSentences: Int");

    const text = textVal.value;
    const maxSentences = maxVal.value;

    // Split into sentences (simple heuristic: split on . ! ?)
    const sentences = text
      .split(/(?<=[.!?])\s+/)
      .filter((s) => s.trim().length > 0);

    const selected = sentences.slice(0, maxSentences);
    const summary = selected.join(" ");

    return CValues.product(
      {
        summary: CValues.string(summary),
        sentenceCount: CValues.int(selected.length),
      },
      {
        summary: CTypes.string(),
        sentenceCount: CTypes.int(),
      }
    );
  },
};
```

## Step 3: Register the Module

Edit `provider-ts/src/index.ts` to import and register the new module.

Add the import at the top:

```typescript
import { summarizeTextModule } from "./modules/summarize-text.js";
```

Add the registration after the existing `provider.register(...)` calls:

```typescript
provider.register(summarizeTextModule);
```

## Step 4: Rebuild and Deploy

Rebuild the TypeScript provider container:

```bash
docker compose up --build provider-ts -d
```

Watch the logs to confirm registration:

```bash
docker compose logs -f provider-ts
```

You should see:

```
[provider-ts] Registered 4 modules:
  - nlp.sentiment.AnalyzeSentiment
  - nlp.sentiment.DetectLanguage
  - nlp.sentiment.ExtractKeywords
  - nlp.sentiment.SummarizeText
```

## Step 5: Verify the Module Is Available

```bash
curl -s http://localhost:8080/modules | jq '.[].name' | grep Summarize
```

You should see `"nlp.sentiment.SummarizeText"`.

## Step 6: Call Your New Module

Create `pipelines/lab-summarize.cst`:

```bash
cat > pipelines/lab-summarize.cst << 'EOF'
use nlp.sentiment

in article: String

summary = SummarizeText(article, 2)
sentiment = AnalyzeSentiment(article)

out summary
out sentiment
EOF
```

Run it:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-summarize.cst | jq -Rs .),
    \"inputs\": {\"article\": \"Machine learning is transforming industries. Companies are investing billions in AI research. The technology enables new applications in healthcare, finance, and transportation. Experts predict significant growth in the coming years.\"}
  }" | jq .outputs
```

**Expected:** The summary contains only the first 2 sentences, plus sentiment analysis of the full article.

## Step 7: Experiment

**Exercise 1:** Modify the module to also return the percentage of text that was kept:

```typescript
// Add to output type:
outputType: CTypes.product({
  summary: CTypes.string(),
  sentenceCount: CTypes.int(),
  compressionRatio: CTypes.float(),  // add this
}),

// In the handler, add:
const ratio = summary.length / text.length;
// Include in the return value
```

Rebuild and test: `docker compose up --build provider-ts -d`

**Exercise 2:** Write a pipeline that summarizes text, then analyzes the sentiment of just the summary (not the full article). Does the sentiment differ?

## Step 8: Remove a Module

To remove a module from the provider:

1. Delete the import and registration from `provider-ts/src/index.ts`
2. Optionally delete the module file
3. Rebuild: `docker compose up --build provider-ts -d`

The module will be deregistered from the server automatically when the provider reconnects.

**Exercise:** Remove `SummarizeText`, rebuild, and verify it's gone:

```bash
curl -s http://localhost:8080/modules | jq '.[].name' | grep Summarize
# Should return nothing
```

Then add it back if you want to keep it.

## Step 9: Clean Up

```bash
rm -f pipelines/lab-summarize.cst
```

If you added `SummarizeText` and want to keep the provider clean, revert the changes to `provider-ts/src/index.ts` and rebuild.

## Checkpoint

You now know how to:
- [x] Define a new TypeScript module with input/output types and a handler
- [x] Register a module with the provider
- [x] Rebuild and deploy the provider container
- [x] Verify module registration via the API
- [x] Call the new module from a pipeline
- [x] Remove a module from the provider

**Next:** [Codelab 6: Adding a Scala Module](06-adding-a-scala-module.md)
