# Codelab 2: Exploring the Dashboard

**Duration:** ~15 minutes
**Difficulty:** Beginner
**Prerequisites:** Demo running, completed Codelab 1

## What You'll Learn

- Navigate the web dashboard
- Browse and select pipeline files
- Run pipelines from the dashboard
- View DAG visualizations of your pipelines

## Step 1: Open the Dashboard

Open your browser and navigate to:

```
http://localhost:8080/dashboard
```

You should see the Constellation dashboard with a file browser on the left showing all `.cst` files from the `pipelines/` directory.

## Step 2: Browse Pipeline Files

The file browser shows all 13 pipeline files. Click on `01-hello-world.cst`.

You should see:
- The pipeline source code in the editor
- Syntax highlighting for constellation-lang

**Exercise:** Click through several pipeline files and notice how they increase in complexity:
- `01` is a single module call
- `06` uses branch expressions
- `10` calls modules from three different sources (built-in + two external providers)

## Step 3: Run a Pipeline

1. Select `01-hello-world.cst` in the file browser
2. The input form should show a field for `greeting` (String)
3. Type a value like `Hello from the dashboard!`
4. Click **Run** (or press `Ctrl+Enter`)
5. The output panel should show `upper: "HELLO FROM THE DASHBOARD!"`

**Exercise:** Try running these pipelines from the dashboard:

| Pipeline | Inputs to Try |
|----------|---------------|
| `02-text-processing` | `rawText`: `"  Hello World!  \nLine two  "` |
| `03-data-aggregation` | `numbers`: `[10, 25, 3, 47]`, `threshold`: `10` |
| `06-branch-logic` | `score`: `85`, `isUrgent`: `true` |

## Step 4: Visualize the DAG

After running a pipeline, look for the **DAG** tab or visualization panel.

The DAG (Directed Acyclic Graph) shows:
- **Input nodes** — the data entering the pipeline
- **Module nodes** — processing steps
- **Output nodes** — the results
- **Edges** — data flow between nodes

**Exercise:** Compare the DAGs of these pipelines:
1. `01-hello-world.cst` — simple linear flow: input → Uppercase → output
2. `10-full-pipeline.cst` — complex fan-out: one input feeds multiple parallel modules

Notice how the DAG visualizes the implicit parallelism — modules that don't depend on each other can run simultaneously.

## Step 5: Try an External Provider Pipeline

Select `08-sentiment-analysis.cst` and run it with:

- `articleText`: `"This is a wonderful and amazing article about great technology!"`
- `maxKeywords`: `5`

You should see outputs from the TypeScript provider:
- `sentiment` — a score and label
- `language` — detected language and confidence
- `keywords` — extracted keyword list

If the providers aren't connected yet, you'll see an error. Check with:

```bash
curl -s http://localhost:8080/modules | jq '.[].name' | grep nlp
```

If you see `nlp.sentiment.AnalyzeSentiment` and friends, the providers are ready.

## Step 6: View Execution History

After running several pipelines, the dashboard may show an execution history panel. This shows:
- Recent executions with timestamps
- Success/failure status
- Execution duration
- Input/output summaries

**Exercise:** Run the same pipeline 3 times with different inputs and observe how the history accumulates.

## Step 7: Explore the API Alongside the Dashboard

The dashboard uses the same HTTP API you've been using with `curl`. Open your browser's developer tools (F12) and watch the Network tab while running a pipeline from the dashboard.

You'll see the same `/run` endpoint being called with the same JSON format.

## Checkpoint

You now know how to:
- [x] Navigate the web dashboard
- [x] Browse pipeline files
- [x] Run pipelines with inputs from the UI
- [x] Read DAG visualizations
- [x] View execution history

**Next:** [Codelab 3: Building a Data Pipeline](03-building-a-data-pipeline.md)
