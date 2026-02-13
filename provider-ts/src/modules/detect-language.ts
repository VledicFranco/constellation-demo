import {
  type ModuleDefinition,
  type CValue,
  CTypes,
  CValues,
} from "@constellation-engine/provider-sdk";

// Simple heuristic markers for language detection
const LANGUAGE_MARKERS: Record<string, string[]> = {
  english: ["the", "is", "are", "was", "were", "have", "has", "been", "will", "would", "could", "should"],
  spanish: ["el", "la", "los", "las", "es", "son", "tiene", "hacer", "como", "pero", "que", "por"],
  french:  ["le", "la", "les", "est", "sont", "avoir", "faire", "comme", "mais", "que", "pour", "dans"],
  german:  ["der", "die", "das", "ist", "sind", "haben", "werden", "nicht", "aber", "und", "ein", "eine"],
};

/** DetectLanguage — heuristic language detection.
 *
 * Input:  { text: String }
 * Output: { language: String, confidence: Float }
 */
export const detectLanguageModule: ModuleDefinition = {
  name: "DetectLanguage",
  inputType: CTypes.product({ text: CTypes.string() }),
  outputType: CTypes.product({ language: CTypes.string(), confidence: CTypes.float() }),
  version: "1.0.0",
  description: "Detect the language of input text using word-frequency heuristics",
  handler: async (input: CValue): Promise<CValue> => {
    if (input.tag !== "CProduct") throw new Error("Expected CProduct input");
    const textVal = input.value["text"];
    if (!textVal || textVal.tag !== "CString") throw new Error("Expected text: String");
    const text = textVal.value.toLowerCase();

    const words = text.split(/\s+/).filter((w) => w.length > 0);
    if (words.length === 0) {
      return CValues.product(
        { language: CValues.string("unknown"), confidence: CValues.float(0.0) },
        { language: CTypes.string(), confidence: CTypes.float() }
      );
    }

    const scores: Record<string, number> = {};
    for (const [lang, markers] of Object.entries(LANGUAGE_MARKERS)) {
      let count = 0;
      for (const word of words) {
        if (markers.includes(word.replace(/[^a-z]/g, ""))) count++;
      }
      scores[lang] = count / words.length;
    }

    let bestLang = "unknown";
    let bestScore = 0;
    for (const [lang, score] of Object.entries(scores)) {
      if (score > bestScore) {
        bestLang = lang;
        bestScore = score;
      }
    }

    // If no markers matched, default to english with low confidence
    if (bestScore === 0) {
      bestLang = "english";
      bestScore = 0.3;
    }

    const confidence = Math.min(1.0, bestScore * 5); // Scale up for better UX

    return CValues.product(
      { language: CValues.string(bestLang), confidence: CValues.float(confidence) },
      { language: CTypes.string(), confidence: CTypes.float() }
    );
  },
};
