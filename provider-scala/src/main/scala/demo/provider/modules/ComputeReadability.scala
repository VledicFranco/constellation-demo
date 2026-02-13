package demo.provider.modules

import cats.effect.IO

import io.constellation.CType
import io.constellation.CValue
import io.constellation.provider.sdk.ModuleDefinition

/** ComputeReadability — Flesch-Kincaid readability scoring.
  *
  * Input: { text: String } Output: { score: Float, grade: String }
  */
object ComputeReadability {

  private def countSyllables(word: String): Int = {
    val w = word.toLowerCase.replaceAll("[^a-z]", "")
    if (w.isEmpty) return 0
    var count  = 0
    var prevVowel = false
    val vowels = Set('a', 'e', 'i', 'o', 'u')
    for (c <- w) {
      val isVowel = vowels.contains(c)
      if (isVowel && !prevVowel) count += 1
      prevVowel = isVowel
    }
    // Adjust: silent 'e' at end
    if (w.endsWith("e") && count > 1) count -= 1
    math.max(count, 1)
  }

  private def scoreToGrade(score: Double): String = score match {
    case s if s >= 90 => "5th grade"
    case s if s >= 80 => "6th grade"
    case s if s >= 70 => "7th grade"
    case s if s >= 60 => "8th-9th grade"
    case s if s >= 50 => "10th-12th grade"
    case s if s >= 30 => "College"
    case _            => "Graduate"
  }

  val module: ModuleDefinition = ModuleDefinition(
    name = "ComputeReadability",
    inputType = CType.CProduct(Map("text" -> CType.CString)),
    outputType = CType.CProduct(Map(
      "score" -> CType.CFloat,
      "grade" -> CType.CString
    )),
    version = "1.0.0",
    description = "Compute Flesch-Kincaid readability score and grade level",
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

        // Split into sentences (period, exclamation, question mark)
        val sentences = text.split("[.!?]+").filter(_.trim.nonEmpty)
        val sentenceCount = math.max(sentences.length, 1)

        // Split into words
        val words = text.split("\\s+").filter(_.nonEmpty)
        val wordCount = math.max(words.length, 1)

        // Count syllables
        val syllableCount = words.map(countSyllables).sum

        // Flesch Reading Ease: 206.835 - 1.015*(words/sentences) - 84.6*(syllables/words)
        val score = 206.835 -
          1.015 * (wordCount.toDouble / sentenceCount) -
          84.6 * (syllableCount.toDouble / wordCount)

        val clampedScore = math.max(0.0, math.min(100.0, score))
        val grade        = scoreToGrade(clampedScore)

        val outType = CType.CProduct(Map("score" -> CType.CFloat, "grade" -> CType.CString))
        CValue.CProduct(
          Map(
            "score" -> CValue.CFloat(clampedScore),
            "grade" -> CValue.CString(grade)
          ),
          outType
        )
      }
    }
  )
}
