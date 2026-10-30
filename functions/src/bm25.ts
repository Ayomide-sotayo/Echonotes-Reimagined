/**
 * BM25 Retrieval & Passage Chunking Engine
 * Provides deterministic, keyword-relevance ranking across collection notes and transcripts.
 */

export interface NoteSource {
  id: string;
  title: string;
  type: string;
  content: string; // transcription or summary
  createdAt?: string;
}

export interface Passage {
  passageId: string;
  noteId: string;
  noteTitle: string;
  type: string;
  text: string;
  tokenCount: number;
  segmentIndex: number;
}

export interface ScoredPassage extends Passage {
  score: number;
}

const STOP_WORDS = new Set([
  'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an', 'and', 'any', 'are', 'aren\'t',
  'as', 'at', 'be', 'because', 'been', 'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can\'t',
  'cannot', 'could', 'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t', 'doing', 'don\'t', 'down',
  'during', 'each', 'few', 'for', 'from', 'further', 'had', 'hadn\'t', 'has', 'hasn\'t', 'have', 'haven\'t',
  'having', 'he', 'he\'d', 'he\'ll', 'he\'s', 'her', 'here', 'here\'s', 'hers', 'herself', 'him', 'himself',
  'his', 'how', 'how\'s', 'i', 'i\'d', 'i\'ll', 'i\'m', 'i\'ve', 'if', 'in', 'into', 'is', 'isn\'t', 'it',
  'it\'s', 'its', 'itself', 'let\'s', 'me', 'more', 'most', 'mustn\'t', 'my', 'myself', 'no', 'nor', 'not',
  'of', 'off', 'on', 'once', 'only', 'or', 'other', 'ought', 'our', 'ours', 'ourselves', 'out', 'over', 'own',
  'same', 'shan\'t', 'she', 'she\'d', 'she\'ll', 'she\'s', 'should', 'shouldn\'t', 'so', 'some', 'such',
  'than', 'that', 'that\'s', 'the', 'their', 'theirs', 'them', 'themselves', 'then', 'there', 'there\'s',
  'these', 'they', 'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through', 'to', 'too',
  'under', 'until', 'up', 'very', 'was', 'wasn\'t', 'we', 'we\'d', 'we\'ll', 'we\'re', 'we\'ve', 'were',
  'weren\'t', 'what', 'what\'s', 'when', 'when\'s', 'where', 'where\'s', 'which', 'while', 'who', 'who\'s',
  'whom', 'why', 'why\'s', 'with', 'won\'t', 'would', 'wouldn\'t', 'you', 'you\'d', 'you\'ll', 'you\'re',
  'you\'ve', 'your', 'yours', 'yourself', 'yourselves'
]);

/**
 * Tokenize text into lowercased terms with stop-word removal.
 */
export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .map(t => t.trim())
    .filter(t => t.length > 1 && !STOP_WORDS.has(t));
}

/**
 * Split note content into overlapping passages.
 * Default: ~350 words with a 50-word overlap.
 */
export function chunkNote(note: NoteSource, chunkSize = 350, overlap = 50): Passage[] {
  const words = note.content.trim().split(/\s+/).filter(w => w.length > 0);
  if (words.length === 0) return [];

  if (words.length <= chunkSize) {
    return [{
      passageId: `${note.id}_p0`,
      noteId: note.id,
      noteTitle: note.title,
      type: note.type,
      text: words.join(' '),
      tokenCount: words.length,
      segmentIndex: 0
    }];
  }

  const passages: Passage[] = [];
  let start = 0;
  let index = 0;

  while (start < words.length) {
    const end = Math.min(start + chunkSize, words.length);
    const slice = words.slice(start, end);

    passages.push({
      passageId: `${note.id}_p${index}`,
      noteId: note.id,
      noteTitle: note.title,
      type: note.type,
      text: slice.join(' '),
      tokenCount: slice.length,
      segmentIndex: index
    });

    if (end >= words.length) break;
    start += (chunkSize - overlap);
    index++;
  }

  return passages;
}

/**
 * BM25 Passage Ranker
 */
export class BM25Ranker {
  private k1: number;
  private b: number;

  constructor(k1 = 1.5, b = 0.75) {
    this.k1 = k1;
    this.b = b;
  }

  /**
   * Rank passages against a user query and return the top-K highest-scoring passages.
   */
  rank(query: string, passages: Passage[], topK = 5): ScoredPassage[] {
    if (passages.length === 0) return [];

    const queryTokens = tokenize(query);
    if (queryTokens.length === 0) {
      // If no valid search tokens (e.g. only stopwords), return first topK passages
      return passages.slice(0, topK).map(p => ({ ...p, score: 0 }));
    }

    const N = passages.length;
    const passageTokensList = passages.map(p => tokenize(p.text));
    const passageLengths = passageTokensList.map(t => t.length);
    const avgdl = passageLengths.reduce((acc, l) => acc + l, 0) / N;

    // Document frequencies: number of passages containing token q
    const docFrequencies = new Map<string, number>();
    for (const q of queryTokens) {
      let count = 0;
      for (const pTokens of passageTokensList) {
        if (pTokens.includes(q)) count++;
      }
      docFrequencies.set(q, count);
    }

    const scored: ScoredPassage[] = passages.map((passage, i) => {
      const pTokens = passageTokensList[i];
      const pLen = passageLengths[i];
      let score = 0;

      // Count term frequencies in this passage
      const termFreqs = new Map<string, number>();
      for (const t of pTokens) {
        termFreqs.set(t, (termFreqs.get(t) || 0) + 1);
      }

      for (const q of queryTokens) {
        const tf = termFreqs.get(q) || 0;
        if (tf === 0) continue;

        const df = docFrequencies.get(q) || 0;
        // Robertson-Spärck Jones IDF
        const idf = Math.log((N - df + 0.5) / (df + 0.5) + 1);

        const numerator = tf * (this.k1 + 1);
        const denominator = tf + this.k1 * (1 - this.b + this.b * (pLen / (avgdl || 1)));

        score += idf * (numerator / denominator);
      }

      return {
        ...passage,
        score
      };
    });

    // Sort descending by score
    scored.sort((a, b) => b.score - a.score);

    // If top passages have positive scores, return topK.
    // If all scores are 0 (no term match), return top passages bounded.
    return scored.slice(0, topK);
  }
}
