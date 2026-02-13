# Codelab 3: Building a Data Pipeline

**Duration:** ~20 minutes
**Difficulty:** Intermediate
**Prerequisites:** Demo running, completed Codelabs 1-2

## What You'll Learn

- Use stdlib functions with `use` imports
- Combine text and data modules in a single pipeline
- Use guards (`when`) and coalesce (`??`) for conditional logic
- Use branch expressions for multi-way decisions
- Use arithmetic and comparison operators

## Step 1: Import and Use Stdlib Functions

The standard library provides math, string, comparison, and boolean functions. You access them with `use`:

Create `pipelines/lab-student-grade.cst`:

```bash
cat > pipelines/lab-student-grade.cst << 'EOF'
# Student Grading Pipeline
# Takes a student name and score, produces a grade report

use stdlib.compare
use stdlib.string
use stdlib.math

in studentName: String
in score: Int
in totalPossible: Int

# Normalize the name
cleanName = Trim(studentName)
displayName = Uppercase(cleanName)

# Calculate percentage (using integer division)
percentage = divide(multiply(score, 100), totalPossible)

# Determine pass/fail
isPassing = gte(percentage, 60)

out displayName
out percentage
out isPassing
EOF
```

Run it:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-student-grade.cst | jq -Rs .),
    \"inputs\": {\"studentName\": \"  alice  \", \"score\": 85, \"totalPossible\": 100}
  }" | jq .outputs
```

**Expected:** `displayName: "ALICE"`, `percentage: 85`, `isPassing: true`

**Exercise:** Try with `score: 45` — what changes?

## Step 2: Add Guards and Coalesce

Guards produce optional values — they only return a value when a condition is true.

Update your pipeline to add conditional messages. Create `pipelines/lab-student-report.cst`:

```bash
cat > pipelines/lab-student-report.cst << 'EOF'
use stdlib.compare
use stdlib.string

in studentName: String
in score: Int

cleanName = Trim(studentName)

# Guards: these produce Optional<String>
# Only one will be Some(...), the rest will be None
excellentMsg = "Outstanding work!" when gte(score, 90)
goodMsg      = "Good job!" when gte(score, 70)
passMsg      = "You passed." when gte(score, 60)

# Coalesce chain: tries each optional left-to-right, returns first Some
message = excellentMsg ?? goodMsg ?? passMsg ?? "Needs improvement."

# Build greeting
greeting = concat("Dear ", concat(cleanName, concat(": ", message)))

out greeting
out score
EOF
```

Run it with different scores:

```bash
# Score 95 → "Outstanding work!"
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-student-report.cst | jq -Rs .),
    \"inputs\": {\"studentName\": \"Alice\", \"score\": 95}
  }" | jq .outputs

# Score 75 → "Good job!"
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-student-report.cst | jq -Rs .),
    \"inputs\": {\"studentName\": \"Bob\", \"score\": 75}
  }" | jq .outputs

# Score 40 → "Needs improvement."
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-student-report.cst | jq -Rs .),
    \"inputs\": {\"studentName\": \"Charlie\", \"score\": 40}
  }" | jq .outputs
```

## Step 3: Use Branch Expressions

Branch expressions are cleaner for multi-way decisions. Create `pipelines/lab-student-branch.cst`:

```bash
cat > pipelines/lab-student-branch.cst << 'EOF'
use stdlib.compare
use stdlib.bool

in score: Int
in isHonors: Boolean

# Letter grade using branch
letterGrade = branch {
  gte(score, 90) -> "A",
  gte(score, 80) -> "B",
  gte(score, 70) -> "C",
  gte(score, 60) -> "D",
  otherwise -> "F"
}

# Honors distinction using boolean operators
distinction = branch {
  isHonors and gte(score, 90) -> "Summa Cum Laude",
  isHonors and gte(score, 80) -> "Magna Cum Laude",
  isHonors and gte(score, 70) -> "Cum Laude",
  otherwise -> "Standard"
}

# Pass/fail using if/else
status = if (gte(score, 60)) "PASS" else "FAIL"

out letterGrade
out distinction
out status
EOF
```

**Exercise:** Run this pipeline with these inputs and predict the outputs before checking:

| score | isHonors | Expected Grade | Expected Distinction | Expected Status |
|-------|----------|---------------|---------------------|----------------|
| 95 | true | ? | ? | ? |
| 82 | true | ? | ? | ? |
| 82 | false | ? | ? | ? |
| 55 | false | ? | ? | ? |

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-student-branch.cst | jq -Rs .),
    \"inputs\": {\"score\": 95, \"isHonors\": true}
  }" | jq .outputs
```

## Step 4: Combine Data Processing

Now let's build a pipeline that processes a list of numbers. Create `pipelines/lab-stats.cst`:

```bash
cat > pipelines/lab-stats.cst << 'EOF'
use stdlib.compare

in scores: List<Int>
in passingThreshold: Int

# Aggregate statistics
total = SumList(scores)
avg = Average(scores)
highest = Max(scores)
lowest = Min(scores)

# Filter to only passing scores
passing = FilterGreaterThan(scores, passingThreshold)
passingCount = SumList([1])

# Format the total for display
formattedTotal = FormatNumber(total)

# Is the average above threshold?
classAvgPassing = gte(avg, passingThreshold)

out avg
out highest
out lowest
out passing
out formattedTotal
out classAvgPassing
EOF
```

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-stats.cst | jq -Rs .),
    \"inputs\": {\"scores\": [92, 78, 65, 88, 45, 73, 91, 56], \"passingThreshold\": 60}
  }" | jq .outputs
```

## Step 5: Clean Up

Remove the lab pipelines if you want to keep the project tidy:

```bash
rm -f pipelines/lab-student-grade.cst pipelines/lab-student-report.cst \
      pipelines/lab-student-branch.cst pipelines/lab-stats.cst \
      pipelines/my-first-pipeline.cst pipelines/multi-input.cst
```

## Checkpoint

You now know how to:
- [x] Import stdlib with `use` declarations
- [x] Call stdlib functions (compare, string, math)
- [x] Use guards (`when`) for conditional optional values
- [x] Chain optionals with coalesce (`??`)
- [x] Write branch expressions for multi-way decisions
- [x] Use if/else expressions
- [x] Combine boolean operators (`and`, `or`, `not`)
- [x] Process lists with data modules

**Next:** [Codelab 4: Calling External Providers](04-calling-external-providers.md)
