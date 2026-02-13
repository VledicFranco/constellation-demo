# Codelab 1: Your First Pipeline

**Duration:** ~15 minutes
**Difficulty:** Beginner
**Prerequisites:** Demo running (`docker compose up --build -d`)

## What You'll Learn

- The structure of a `.cst` pipeline file
- How to compile a pipeline
- How to execute a pipeline with inputs
- How to read pipeline outputs

## Step 1: Understand the Pipeline Format

A Constellation pipeline has three sections:

```
1. INPUTS    — declare what data the pipeline needs
2. BODY      — process data through module calls
3. OUTPUTS   — declare what data the pipeline returns
```

Open `pipelines/01-hello-world.cst` and read it:

```bash
cat pipelines/01-hello-world.cst
```

You'll see:

```constellation
in greeting: String       # INPUT: expects a string called "greeting"
upper = Uppercase(greeting)  # BODY: call Uppercase module
out upper                 # OUTPUT: return the result
```

## Step 2: Compile the Pipeline

Compilation checks syntax, types, and module references without running anything.

```bash
curl -s -X POST http://localhost:8080/compile \
  -H "Content-Type: application/json" \
  -d '{"source": "in greeting: String\nupper = Uppercase(greeting)\nout upper"}' | jq .
```

You should see a response with `"structuralHash"` — this is the pipeline's content-addressed identifier.

**Try breaking it:** Change `Uppercase` to `DoesNotExist` and compile again. You should get a compilation error.

## Step 3: Run the Pipeline

Now execute the pipeline with an actual input:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d '{
    "source": "in greeting: String\nupper = Uppercase(greeting)\nout upper",
    "inputs": {"greeting": "Hello, Constellation!"}
  }' | jq .
```

**Expected output:**

```json
{
  "outputs": {
    "upper": "HELLO, CONSTELLATION!"
  }
}
```

## Step 4: Write Your Own Pipeline

Create a new file `pipelines/my-first-pipeline.cst`:

```bash
cat > pipelines/my-first-pipeline.cst << 'EOF'
# My first pipeline!
# Takes a name and produces a greeting

in name: String

lower = Lowercase(name)
trimmed = Trim(lower)
length = TextLength(trimmed)
words = WordCount(trimmed)

out trimmed
out length
out words
EOF
```

Now run it:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/my-first-pipeline.cst | jq -Rs .),
    \"inputs\": {\"name\": \"  Alice Wonderland  \"}
  }" | jq .
```

**Expected output:**

```json
{
  "outputs": {
    "trimmed": "alice wonderland",
    "length": 16,
    "words": 2
  }
}
```

## Step 5: Use Multiple Inputs

Pipelines can take multiple inputs of different types. Create `pipelines/multi-input.cst`:

```bash
cat > pipelines/multi-input.cst << 'EOF'
in text: String
in times: Int

upper = Uppercase(text)
length = TextLength(text)
product = MultiplyEach([times], 2)

out upper
out length
out product
EOF
```

Run it:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/multi-input.cst | jq -Rs .),
    \"inputs\": {\"text\": \"hello\", \"times\": 5}
  }" | jq .
```

## Step 6: Check Available Modules

Want to know what modules you can use? List them:

```bash
curl -s http://localhost:8080/modules | jq '.[].name'
```

This shows all registered modules — both built-in (stdlib, text, data) and external (from providers).

## Checkpoint

You now know how to:
- [x] Read a `.cst` pipeline file
- [x] Compile a pipeline to check for errors
- [x] Execute a pipeline with inputs and read outputs
- [x] Write your own pipeline from scratch
- [x] List available modules

**Next:** [Codelab 2: Exploring the Dashboard](02-exploring-the-dashboard.md)
