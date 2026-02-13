import {
  type ModuleDefinition,
  type CValue,
  CTypes,
  CValues,
} from "@constellation-engine/provider-sdk";

// Positive and negative word lists for keyword-based sentiment analysis
const POSITIVE_WORDS = new Set([
  "good", "great", "excellent", "amazing", "wonderful", "fantastic", "love",
  "happy", "joy", "beautiful", "perfect", "best", "brilliant", "outstanding",
  "superb", "delightful", "pleasant", "impressive", "awesome", "nice",
  "positive", "success", "win", "celebrate", "grateful", "thankful",
]);

const NEGATIVE_WORDS = new Set([
  "bad", "terrible", "awful", "horrible", "hate", "angry", "sad",
  "worst", "ugly", "poor", "disappointing", "dreadful", "miserable",
  "pathetic", "disgusting", "annoying", "frustrating", "painful", "fail",
  "negative", "loss", "disaster", "tragic", "unfortunate", "regret",
]);

/** AnalyzeSentiment — keyword-based sentiment scoring.
 *
 * Input:  { text: String }
 * Output: { score: Float, label: String }
 *
 * Score ranges from -1.0 (very negative) to 1.0 (very positive).
 * Label is one of: "positive", "negative", "neutral".
 */
export const analyzeSentimentModule: ModuleDefinition = {
  name: "AnalyzeSentiment",
  inputType: CTypes.product({ text: CTypes.string() }),
  outputType: CTypes.product({ score: CTypes.float(), label: CTypes.string() }),
  version: "1.0.0",
  description: "Analyze text sentiment using keyword-based scoring (-1.0 to 1.0)",
  handler: async (input: CValue): Promise<CValue> => {
    if (input.tag !== "CProduct") throw new Error("Expected CProduct input");
    const textVal = input.value["text"];
    if (!textVal || textVal.tag !== "CString") throw new Error("Expected text: String");
    const text = textVal.value.toLowerCase();

    const words = text.split(/\s+/).filter((w) => w.length > 0);
    if (words.length === 0) {
      return CValues.product(
        { score: CValues.float(0.0), label: CValues.string("neutral") },
        { score: CTypes.float(), label: CTypes.string() }
      );
    }

    let positiveCount = 0;
    let negativeCount = 0;
    for (const word of words) {
      const cleaned = word.replace(/[^a-z]/g, "");
      if (POSITIVE_WORDS.has(cleaned)) positiveCount++;
      if (NEGATIVE_WORDS.has(cleaned)) negativeCount++;
    }

    const score = (positiveCount - negativeCount) / words.length;
    const clampedScore = Math.max(-1.0, Math.min(1.0, score));
    const label = clampedScore > 0.05 ? "positive" : clampedScore < -0.05 ? "negative" : "neutral";

    return CValues.product(
      { score: CValues.float(clampedScore), label: CValues.string(label) },
      { score: CTypes.float(), label: CTypes.string() }
    );
  },
};
