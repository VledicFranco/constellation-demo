# External Providers

Constellation Engine supports external module providers that connect via gRPC. This demo includes two providers — one in TypeScript and one in Scala — demonstrating the Module Provider SDK in both languages.

## TypeScript Provider (`nlp.sentiment`)

**Source:** `provider-ts/`
**Port:** 50051 (gRPC executor)
**SDK:** `@constellation-engine/provider-sdk` v0.7.0

### Modules

| Module | Input | Output | Description |
|--------|-------|--------|-------------|
| `AnalyzeSentiment` | `{text: String}` | `{score: Float, label: String}` | Keyword-based sentiment scoring. Score ranges -1.0 (negative) to 1.0 (positive). Label: "positive", "negative", or "neutral". |
| `DetectLanguage` | `{text: String}` | `{language: String, confidence: Float}` | Heuristic language detection using word-frequency markers. Supports English, Spanish, French, German. |
| `ExtractKeywords` | `{text: String, maxKeywords: Int}` | `{keywords: List<String>}` | TF-based keyword extraction. Filters stop words, returns top N terms by frequency. |

### Usage in constellation-lang

```constellation
use nlp.sentiment

in text: String
sentiment = AnalyzeSentiment(text)
language = DetectLanguage(text)
keywords = ExtractKeywords(text, 5)

out sentiment
out language
out keywords
```

### Implementation

Each module is defined as a `ModuleDefinition` with:
- **Input/output types** using `CTypes` factory helpers
- **Async handler** `(input: CValue) => Promise<CValue>`
- Modules are registered with `provider.register(module)` before calling `provider.start()`

The provider connects to the constellation server's gRPC port (9090) and registers under the `nlp.sentiment` namespace. The server can then dispatch execution requests back to the provider's executor port (50051).

### TS SDK Dependency

For **local development**, `package.json` uses a `file:` reference:

```json
"@constellation-engine/provider-sdk": "file:../../constellation-engine/sdks/typescript"
```

For **Docker builds**, `scripts/setup.sh` runs `npm pack` to create a `.tgz` tarball that gets copied into the build context.

---

## Scala Provider (`nlp.entities`)

**Source:** `provider-scala/`
**Port:** 50052 (gRPC executor)
**SDK:** `constellation-module-provider-sdk` v0.7.0

### Modules

| Module | Input | Output | Description |
|--------|-------|--------|-------------|
| `ExtractEntities` | `{text: String}` | `{entities: List<{name: String, entityType: String}>}` | Regex-based named entity recognition. Detects PERSON (Mr./Dr. prefix), ORGANIZATION (Inc/Corp suffix), LOCATION (in/at/from prefix), and generic ENTITY (capitalized phrases). |
| `ClassifyTopic` | `{text: String}` | `{topic: String, confidence: Float}` | Keyword-based topic classification into: technology, science, business, sports, health, or general. |
| `ComputeReadability` | `{text: String}` | `{score: Float, grade: String}` | Flesch-Kincaid readability score (0-100) and grade level (5th grade through Graduate). |

### Usage in constellation-lang

```constellation
use nlp.entities

in text: String
entities    = ExtractEntities(text)
topic       = ClassifyTopic(text)
readability = ComputeReadability(text)

out entities
out topic
out readability
```

### Implementation

Each module is a `ModuleDefinition` case class with:
- **Input/output types** using `CType.CProduct(Map(...))` constructors
- **IO handler** `(input: CValue) => IO[CValue]`
- Uses `CValue.CProduct`, `CValue.CString`, `CValue.CFloat`, `CValue.CList` constructors

The provider uses `ConstellationProvider.create(...)` with a `GrpcProviderTransport` to connect to the server and a `GrpcExecutorServerFactory` to serve execution requests.

---

## Adding a New Provider

### TypeScript

1. Create a new module file in `provider-ts/src/modules/`:

```typescript
import { type ModuleDefinition, CTypes, CValues } from "@constellation-engine/provider-sdk";

export const myModule: ModuleDefinition = {
  name: "MyModule",
  inputType: CTypes.product({ text: CTypes.string() }),
  outputType: CTypes.product({ result: CTypes.string() }),
  version: "1.0.0",
  description: "My custom module",
  handler: async (input) => {
    const text = input.value["text"].value;
    return CValues.product(
      { result: CValues.string(text.toUpperCase()) },
      { result: CTypes.string() }
    );
  },
};
```

2. Register it in `provider-ts/src/index.ts`:

```typescript
import { myModule } from "./modules/my-module.js";
provider.register(myModule);
```

3. Rebuild: `docker compose up --build provider-ts`

### Scala

1. Create a new module file in `provider-scala/src/main/scala/demo/provider/modules/`:

```scala
import cats.effect.IO
import io.constellation.{CType, CValue}
import io.constellation.provider.sdk.ModuleDefinition

object MyModule {
  val module: ModuleDefinition = ModuleDefinition(
    name = "MyModule",
    inputType = CType.CProduct(Map("text" -> CType.CString)),
    outputType = CType.CProduct(Map("result" -> CType.CString)),
    version = "1.0.0",
    description = "My custom module",
    handler = { (input: CValue) =>
      IO {
        val text = input.asInstanceOf[CValue.CProduct].value("text").asInstanceOf[CValue.CString].value
        CValue.CProduct(Map("result" -> CValue.CString(text.toUpperCase)),
          CType.CProduct(Map("result" -> CType.CString)))
      }
    }
  )
}
```

2. Register it in `provider-scala/src/main/scala/demo/provider/Main.scala`:

```scala
_ <- provider.register(MyModule.module)
```

3. Rebuild: `docker compose up --build provider-scala`
