package demo.provider.modules

import cats.effect.IO

import io.constellation.CType
import io.constellation.CValue
import io.constellation.provider.sdk.ModuleDefinition

/** ClassifyTopic — keyword-based topic classification.
  *
  * Input: { text: String } Output: { topic: String, confidence: Float }
  */
object ClassifyTopic {

  private val topicKeywords: Map[String, Set[String]] = Map(
    "technology" -> Set(
      "software", "hardware", "computer", "ai", "machine", "learning",
      "data", "algorithm", "code", "programming", "tech", "digital",
      "internet", "cloud", "server", "database", "api", "web"
    ),
    "science" -> Set(
      "research", "experiment", "theory", "hypothesis", "study",
      "scientific", "biology", "chemistry", "physics", "laboratory",
      "discovery", "analysis", "evidence", "observation"
    ),
    "business" -> Set(
      "market", "revenue", "profit", "company", "startup", "investment",
      "stock", "finance", "economy", "trade", "sales", "growth",
      "customer", "strategy", "management", "ceo"
    ),
    "sports" -> Set(
      "game", "team", "player", "score", "championship", "league",
      "match", "tournament", "win", "loss", "coach", "athlete",
      "season", "goal", "ball", "race"
    ),
    "health" -> Set(
      "medical", "health", "disease", "treatment", "doctor", "patient",
      "hospital", "medicine", "diagnosis", "symptom", "therapy",
      "vaccine", "clinical", "wellness", "nutrition"
    )
  )

  val module: ModuleDefinition = ModuleDefinition(
    name = "ClassifyTopic",
    inputType = CType.CProduct(Map("text" -> CType.CString)),
    outputType = CType.CProduct(Map(
      "topic"      -> CType.CString,
      "confidence" -> CType.CFloat
    )),
    version = "1.0.0",
    description = "Classify text into a topic category using keyword matching",
    handler = { (input: CValue) =>
      IO {
        val text = input match {
          case CValue.CProduct(fields, _) =>
            fields("text") match {
              case CValue.CString(v) => v
              case _                 => throw new RuntimeException("Expected text: String")
            }
          case _ => throw new RuntimeException("Expected CProduct input")
        }

        val words = text.toLowerCase.split("\\s+").map(_.replaceAll("[^a-z]", "")).toSet

        val scores = topicKeywords.map { case (topic, keywords) =>
          val matchCount = words.intersect(keywords).size
          topic -> (matchCount.toDouble / math.max(words.size, 1))
        }

        val (bestTopic, bestScore) = scores.maxByOption(_._2).getOrElse(("general" -> 0.0))
        val topic      = if (bestScore > 0) bestTopic else "general"
        val confidence = math.min(1.0, bestScore * 10)

        val outType = CType.CProduct(Map("topic" -> CType.CString, "confidence" -> CType.CFloat))
        CValue.CProduct(
          Map(
            "topic"      -> CValue.CString(topic),
            "confidence" -> CValue.CFloat(confidence)
          ),
          outType
        )
      }
    }
  )
}
