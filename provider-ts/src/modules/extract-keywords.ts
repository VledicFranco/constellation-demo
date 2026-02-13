import {
  type ModuleDefinition,
  type CValue,
  CTypes,
  CValues,
} from "@constellation-engine/provider-sdk";

// Common stop words to exclude from keyword extraction
const STOP_WORDS = new Set([
  "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
  "have", "has", "had", "do", "does", "did", "will", "would", "could",
  "should", "may", "might", "shall", "can", "need", "dare", "ought",
  "to", "of", "in", "for", "on", "with", "at", "by", "from", "as",
  "into", "through", "during", "before", "after", "above", "below",
  "between", "out", "off", "over", "under", "again", "further", "then",
  "once", "here", "there", "when", "where", "why", "how", "all", "each",
  "every", "both", "few", "more", "most", "other", "some", "such", "no",
  "not", "only", "own", "same", "so", "than", "too", "very", "just",
  "because", "but", "and", "or", "if", "while", "that", "this", "it",
  "i", "me", "my", "we", "our", "you", "your", "he", "him", "his",
  "she", "her", "they", "them", "their", "what", "which", "who",
]);

/** ExtractKeywords — TF-based keyword extraction.
 *
 * Input:  { text: String, maxKeywords: Int }
 * Output: { keywords: List<String> }
 */
export const extractKeywordsModule: ModuleDefinition = {
  name: "ExtractKeywords",
  inputType: CTypes.product({ text: CTypes.string(), maxKeywords: CTypes.int() }),
  outputType: CTypes.product({ keywords: CTypes.list(CTypes.string()) }),
  version: "1.0.0",
  description: "Extract top keywords from text using term frequency",
  handler: async (input: CValue): Promise<CValue> => {
    if (input.tag !== "CProduct") throw new Error("Expected CProduct input");
    const textVal = input.value["text"];
    const maxVal = input.value["maxKeywords"];
    if (!textVal || textVal.tag !== "CString") throw new Error("Expected text: String");
    if (!maxVal || maxVal.tag !== "CInt") throw new Error("Expected maxKeywords: Int");

    const text = textVal.value.toLowerCase();
    const maxKeywords = maxVal.value;

    // Tokenize and filter stop words
    const words = text
      .split(/[^a-z0-9]+/)
      .filter((w) => w.length > 2 && !STOP_WORDS.has(w));

    // Count term frequency
    const freq = new Map<string, number>();
    for (const word of words) {
      freq.set(word, (freq.get(word) ?? 0) + 1);
    }

    // Sort by frequency descending and take top N
    const sorted = [...freq.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, maxKeywords)
      .map(([word]) => word);

    const keywordValues = sorted.map((kw) => CValues.string(kw));

    return CValues.product(
      { keywords: CValues.list(keywordValues, CTypes.string()) },
      { keywords: CTypes.list(CTypes.string()) }
    );
  },
};
