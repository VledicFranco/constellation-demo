# Codelab 6: Adding a Scala Module

**Duration:** ~30 minutes
**Difficulty:** Advanced
**Prerequisites:** Demo running, completed Codelabs 1-4, basic Scala knowledge

## What You'll Learn

- Define a new module using the Scala Provider SDK
- Understand CType and CValue constructors
- Register and deploy the module
- Call it from a pipeline
- Remove the module

## Step 1: Plan Your Module

We'll build a `CountWords` module that counts word frequency in a text — useful for content analysis.

| Property | Value |
|----------|-------|
| Name | `CountWords` |
| Namespace | `nlp.entities` (same as existing Scala provider) |
| Input | `{ text: String, topN: Int }` |
| Output | `{ words: List<{ word: String, count: Int }> }` |

## Step 2: Create the Module File

Create `provider-scala/src/main/scala/demo/provider/modules/CountWords.scala`:

```scala
package demo.provider.modules

import cats.effect.IO

import io.constellation.CType
import io.constellation.CValue
import io.constellation.provider.sdk.ModuleDefinition

/** CountWords — word frequency analysis.
  *
  * Tokenizes text, counts occurrences, and returns the top N words.
  */
object CountWords {

  // Common stop words to exclude
  private val stopWords = Set(
    "the", "a", "an", "is", "are", "was", "were", "be", "been",
    "have", "has", "had", "do", "does", "did", "will", "would",
    "to", "of", "in", "for", "on", "with", "at", "by", "from",
    "and", "or", "but", "not", "this", "that", "it", "as"
  )

  private val wordRecordType = CType.CProduct(Map(
    "word"  -> CType.CString,
    "count" -> CType.CInt
  ))

  val module: ModuleDefinition = ModuleDefinition(
    name = "CountWords",
    inputType = CType.CProduct(Map(
      "text" -> CType.CString,
      "topN" -> CType.CInt
    )),
    outputType = CType.CProduct(Map(
      "words" -> CType.CList(wordRecordType)
    )),
    version = "1.0.0",
    description = "Count word frequencies and return top N words",
    handler = { (input: CValue) =>
      IO {
        val fields = input match {
          case CValue.CProduct(f, _) => f
          case _ => throw new RuntimeException("Expected CProduct")
        }
        val text = fields("text") match {
          case CValue.CString(v) => v
          case _ => throw new RuntimeException("Expected text: String")
        }
        val topN = fields("topN") match {
          case CValue.CInt(v) => v.toInt
          case _ => throw new RuntimeException("Expected topN: Int")
        }

        // Tokenize and count
        val words = text.toLowerCase
          .split("[^a-z0-9]+")
          .filter(w => w.length > 2 && !stopWords.contains(w))

        val freq = words.groupBy(identity).view.mapValues(_.length).toList
        val topWords = freq.sortBy(-_._2).take(topN)

        // Build CValue result
        // CValue.CProduct accepts either Map[String, CType] or CType.CProduct as structure
        val wordValues = topWords.map { case (word, count) =>
          CValue.CProduct(
            Map("word" -> CValue.CString(word), "count" -> CValue.CInt(count.toLong)),
            wordRecordType   // CType.CProduct — convenience overload extracts the Map
          )
        }.toVector

        val outType = CType.CProduct(Map("words" -> CType.CList(wordRecordType)))
        CValue.CProduct(
          Map("words" -> CValue.CList(wordValues, wordRecordType)),
          outType
        )
      }
    }
  )
}
```

## Step 3: Register the Module

Edit `provider-scala/src/main/scala/demo/provider/Main.scala`.

Add the import:

```scala
import demo.provider.modules.{ClassifyTopic, ComputeReadability, CountWords, ExtractEntities}
```

Add the registration after the existing ones:

```scala
_ <- provider.register(CountWords.module)
```

## Step 4: Rebuild and Deploy

```bash
docker compose up --build provider-scala -d
```

This takes a bit longer than TypeScript because sbt needs to compile. Watch progress:

```bash
docker compose logs -f provider-scala
```

You should see:

```
[provider-scala] Registered 4 modules:
  - nlp.entities.ExtractEntities
  - nlp.entities.ClassifyTopic
  - nlp.entities.ComputeReadability
  - nlp.entities.CountWords
```

## Step 5: Verify Registration

```bash
curl -s http://localhost:8080/modules | jq '.[].name' | grep CountWords
```

Should output: `"nlp.entities.CountWords"`

## Step 6: Call Your New Module

Create `pipelines/lab-word-freq.cst`:

```bash
cat > pipelines/lab-word-freq.cst << 'EOF'
use nlp.entities

in article: String

# Count the top 5 most frequent words
wordFreq = CountWords(article, 5)

# Also get the topic for comparison
topic = ClassifyTopic(article)

out wordFreq
out topic
EOF
```

Run it:

```bash
curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d "{
    \"source\": $(cat pipelines/lab-word-freq.cst | jq -Rs .),
    \"inputs\": {\"article\": \"Machine learning algorithms are transforming software development. Deep learning models and neural networks power artificial intelligence applications. Machine learning enables computers to learn from data without explicit programming.\"}
  }" | jq .outputs
```

**Expected:** The top words should include "learning", "machine", etc.

## Step 7: Understand CType and CValue

The key types used in Scala module definitions:

**CType** (type descriptors):
```scala
CType.CString                              // String
CType.CInt                                 // Int (Long)
CType.CFloat                               // Float (Double)
CType.CBoolean                             // Boolean
CType.CList(CType.CString)                 // List<String>
CType.CProduct(Map("x" -> CType.CInt))     // { x: Int }
```

**CValue** (runtime values):
```scala
CValue.CString("hello")                              // "hello"
CValue.CInt(42L)                                     // 42
CValue.CFloat(3.14)                                  // 3.14
CValue.CBoolean(true)                                // true
CValue.CList(Vector(...), elementType)                // [...]
CValue.CProduct(Map(...), Map[String, CType](...))    // { ... } (explicit)
CValue.CProduct(Map(...), CType.CProduct(Map(...)))   // { ... } (convenience)
```

> **Tip:** `CValue.CProduct` accepts either `Map[String, CType]` or `CType.CProduct` as the structure parameter. The convenience form is often cleaner when you already have the type defined.

**Exercise:** Modify `CountWords` to also return the total number of unique words. Add a `uniqueCount: Int` field to the output type and value.

## Step 8: Remove a Module

To remove a module:

1. Remove the registration line from `Main.scala`
2. Optionally delete the module file
3. Rebuild: `docker compose up --build provider-scala -d`

**Exercise:** Remove `CountWords`, rebuild, verify it's gone, then add it back.

## Step 9: Clean Up

```bash
rm -f pipelines/lab-word-freq.cst
```

Revert provider changes if you want a clean state.

## Checkpoint

You now know how to:
- [x] Define a Scala module with CType input/output
- [x] Implement a handler that processes CValue inputs
- [x] Construct CValue results including nested records and lists
- [x] Register, deploy, and verify a new Scala module
- [x] Remove a module from the provider

**Next:** [Codelab 7: Resilience & Caching](07-resilience-and-caching.md)
