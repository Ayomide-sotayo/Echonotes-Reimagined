import { describe, it } from 'node:test';
import * as assert from 'node:assert';
import { tokenize, chunkNote, BM25Ranker, NoteSource } from '../src/bm25';

describe('BM25 & Retrieval Engine Unit Tests', () => {

  it('tokenize should lowercase, remove punctuation and strip stop words', () => {
    const raw = 'The Apostle Paul wrote about Faith, Grace, and the Law in Romans!';
    const tokens = tokenize(raw);

    assert.ok(tokens.includes('apostle'));
    assert.ok(tokens.includes('paul'));
    assert.ok(tokens.includes('faith'));
    assert.ok(tokens.includes('grace'));
    assert.ok(tokens.includes('law'));
    assert.ok(tokens.includes('romans'));
    assert.ok(!tokens.includes('the'));
    assert.ok(!tokens.includes('and'));
    assert.ok(!tokens.includes('in'));
  });

  it('chunkNote should keep small notes as a single passage', () => {
    const note: NoteSource = {
      id: 'note_1',
      title: 'Brief Reflection',
      type: 'text',
      content: 'This is a brief reflection on Christian ethics.'
    };

    const passages = chunkNote(note, 350, 50);
    assert.strictEqual(passages.length, 1);
    assert.strictEqual(passages[0].passageId, 'note_1_p0');
    assert.strictEqual(passages[0].noteId, 'note_1');
    assert.strictEqual(passages[0].segmentIndex, 0);
  });

  it('chunkNote should split long lecture transcripts into overlapping chunks', () => {
    // Generate a 900-word lecture transcript
    const words: string[] = [];
    for (let i = 0; i < 900; i++) {
      words.push(`word${i}`);
    }
    const note: NoteSource = {
      id: 'lecture_theology_1',
      title: 'Romans Lecture 1',
      type: 'audio',
      content: words.join(' ')
    };

    const passages = chunkNote(note, 350, 50);
    // 900 words with 350 chunk and 50 overlap -> ~3 chunks
    assert.ok(passages.length >= 3);
    assert.strictEqual(passages[0].passageId, 'lecture_theology_1_p0');
    assert.strictEqual(passages[1].passageId, 'lecture_theology_1_p1');
    assert.strictEqual(passages[2].passageId, 'lecture_theology_1_p2');

    // Verify overlap: words at the boundary of chunk 0 should appear in chunk 1
    const chunk0Words = passages[0].text.split(' ');
    const chunk1Words = passages[1].text.split(' ');
    const overlapWords = chunk0Words.slice(300, 350);
    assert.ok(chunk1Words.slice(0, 50).join(' ') === overlapWords.join(' '));
  });

  it('BM25Ranker should rank the most relevant note chunk highest', () => {
    const noteA: NoteSource = {
      id: 'note_a',
      title: 'Lecture on Faith and Justification',
      type: 'audio',
      content: 'Paul emphasizes that justification is received through faith alone and not through works of the law.'
    };

    const noteB: NoteSource = {
      id: 'note_b',
      title: 'Church History Overview',
      type: 'audio',
      content: 'The council of Nicaea gathered bishops from across the Roman empire to discuss the creed.'
    };

    const noteC: NoteSource = {
      id: 'note_c',
      title: 'Hebrew Poetry in Psalms',
      type: 'text',
      content: 'Parallelism is the defining structural feature of ancient biblical Hebrew poetry and laments.'
    };

    const passages = [
      ...chunkNote(noteA),
      ...chunkNote(noteB),
      ...chunkNote(noteC)
    ];

    const ranker = new BM25Ranker();
    const results = ranker.rank('What did the lecture teach about justification by faith?', passages, 3);

    assert.ok(results.length > 0);
    assert.strictEqual(results[0].noteId, 'note_a');
    assert.ok(results[0].score > 0);
    // Church history and Hebrew poetry should have lower or zero score for 'justification faith'
    if (results.length > 1) {
      assert.ok(results[0].score > results[1].score);
    }
  });

  it('BM25Ranker should handle queries with terms not present in collection', () => {
    const note: NoteSource = {
      id: 'note_x',
      title: 'General Announcements',
      type: 'text',
      content: 'Please remember that the library will be closed next Monday for national maintenance.'
    };

    const passages = chunkNote(note);
    const ranker = new BM25Ranker();
    const results = ranker.rank('Quantum physics and dark matter thermodynamics', passages, 3);

    // Should return safely with 0 score without throwing
    assert.strictEqual(results.length, 1);
    assert.strictEqual(results[0].score, 0);
  });
});
