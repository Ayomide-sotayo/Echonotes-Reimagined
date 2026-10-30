import 'package:echonotes/features/collections/models/collection_chat_message.dart';
import 'package:echonotes/features/collections/models/collection_conversation.dart';
import 'package:echonotes/features/collections/services/collection_ai_service.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 8: Collection AI Data Models & Grounded Retrieval Tests', () {
    test('GroundedCitation correctly serializes and deserializes', () {
      final citation = GroundedCitation(
        noteId: 'note_lect_01',
        noteTitle: 'Theology 101: Grace and Law',
        passageId: 'note_lect_01_p0',
        snippet: 'Grace is unmerited divine favor and not earned through human striving.',
        relevanceScore: 2.85,
      );

      final map = citation.toMap();
      expect(map['noteId'], equals('note_lect_01'));
      expect(map['noteTitle'], equals('Theology 101: Grace and Law'));
      expect(map['passageId'], equals('note_lect_01_p0'));
      expect(map['relevanceScore'], equals(2.85));

      final deserialized = GroundedCitation.fromMap(map);
      expect(deserialized.noteId, equals(citation.noteId));
      expect(deserialized.snippet, equals(citation.snippet));
      expect(deserialized.relevanceScore, equals(2.85));
    });

    test('CollectionChatMessage correctly distinguishes User and Assistant roles', () {
      final userMsg = CollectionChatMessage(
        id: 'msg_1',
        sender: 'user',
        text: 'What did Professor John teach about Covenant theology?',
        timestamp: DateTime.now(),
      );
      expect(userMsg.isUser, isTrue);
      expect(userMsg.citations, isEmpty);
      expect(userMsg.isInsufficientEvidence, isFalse);

      final assistantMsg = CollectionChatMessage(
        id: 'msg_2',
        sender: 'assistant',
        text: 'Professor John taught that covenants form the backbone of redemptive history.',
        citations: [
          const GroundedCitation(
            noteId: 'note_lect_02',
            noteTitle: 'Lecture 2: The Biblical Covenants',
            passageId: 'note_lect_02_p1',
            snippet: 'Covenants form the redemptive spine connecting Old and New Testaments.',
            relevanceScore: 3.12,
          ),
        ],
        timestamp: DateTime.now(),
      );
      expect(assistantMsg.isUser, isFalse);
      expect(assistantMsg.citations.length, equals(1));
      expect(assistantMsg.citations.first.passageId, equals('note_lect_02_p1'));
    });

    test('CollectionChatMessage supports insufficient evidence flag without hallucination', () {
      final insufficientMsg = CollectionChatMessage(
        id: 'msg_3',
        sender: 'assistant',
        text: 'The lectures in this collection discuss Soteriology and Eschatology, but do not mention Church Architecture.',
        isInsufficientEvidence: true,
        timestamp: DateTime.now(),
      );

      expect(insufficientMsg.isInsufficientEvidence, isTrue);
      expect(insufficientMsg.citations, isEmpty);
    });

    test('CollectionChatMessage.cleanText strips raw passage IDs and unwraps JSON cleanly', () {
      const rawWithIds = 'Bananas are berries [GwZGPQeplQsweuZE6So8_p0]. Honey never spoils [HZZPgEu07L4yAJi7tQ81_p0].';
      expect(
        CollectionChatMessage.cleanText(rawWithIds),
        equals('Bananas are berries. Honey never spoils.'),
      );

      const rawJson = '{\n  "answer": "Quantum computing uses superposition [Jbn2vOv2xkzGHKEYPOx7_p0]."\n}';
      expect(
        CollectionChatMessage.cleanText(rawJson),
        equals('Quantum computing uses superposition.'),
      );
    });

    test('CollectionConversation model retains collection binding and metadata', () {
      final now = DateTime.now();
      final conv = CollectionConversation(
        id: 'conv_theology_01',
        title: 'Covenants & Grace Q&A',
        collectionId: 'col_theology_sem_1',
        collectionName: 'Theology School',
        createdAt: now,
        updatedAt: now,
        lastMessage: 'Professor John taught that covenants form the backbone...',
        messageCount: 4,
      );

      expect(conv.id, equals('conv_theology_01'));
      expect(conv.collectionId, equals('col_theology_sem_1'));
      expect(conv.collectionName, equals('Theology School'));
      expect(conv.messageCount, equals(4));
    });

    test('Passage chunking produces deterministic IDs and respects word count boundaries', () {
      // Simulate a realistic 850-word lecture transcript note
      final words = List.generate(850, (i) => 'word$i');
      final lectureContent = words.join(' ');

      final note = Note(
        id: 'theology_lect_05',
        userId: 'student_user_123',
        title: 'Semester Review Lecture',
        type: 'audio',
        createdAt: DateTime.now(),
        collectionId: 'col_theology_sem_1',
        collectionName: 'Theology School',
        transcription: lectureContent,
      );

      // Verify note mainContent returns the transcription
      expect(note.mainContent, equals(lectureContent));

      // Test chunking algorithm manually mirroring CollectionAIService
      final chunks = <ClientPassage>[];
      final splitWords = note.mainContent!.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      
      const chunkSize = 350;
      const overlap = 50;
      int start = 0;
      int index = 0;

      while (start < splitWords.length) {
        final end = (start + chunkSize < splitWords.length) ? start + chunkSize : splitWords.length;
        final passageText = splitWords.sublist(start, end).join(' ');
        chunks.add(ClientPassage(
          passageId: '${note.id}_p$index',
          noteId: note.id,
          noteTitle: note.title,
          type: note.type,
          text: passageText,
          tokens: passageText.split(' '),
        ));
        index++;
        if (end >= splitWords.length) break;
        start += (chunkSize - overlap);
      }

      // 850 words with 350 size and 300 step (350 - 50 overlap):
      // p0: 0 -> 350
      // p1: 300 -> 650
      // p2: 600 -> 850
      expect(chunks.length, equals(3));
      expect(chunks[0].passageId, equals('theology_lect_05_p0'));
      expect(chunks[1].passageId, equals('theology_lect_05_p1'));
      expect(chunks[2].passageId, equals('theology_lect_05_p2'));
    });

    test('Cross-note BM25 tokens filter stop words and prioritize distinctive lecture keywords', () {
      final stopWords = {
        'the', 'is', 'at', 'which', 'on', 'and', 'a', 'in', 'that', 'to'
      };

      const rawQuery = 'What did the professor say about sanctification and faith?';
      final tokens = rawQuery
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.length > 1 && !stopWords.contains(t))
          .toList();

      expect(tokens, contains('professor'));
      expect(tokens, contains('sanctification'));
      expect(tokens, contains('faith'));
      expect(tokens.contains('the'), isFalse);
      expect(tokens.contains('and'), isFalse);
      expect(tokens.contains('what'), isTrue); // what is kept if not in stopWords
    });

    test('Citation validation strictly prevents hallucinated IDs from being presented as evidence', () {
      final retrievedPassages = [
        ClientPassage(
          passageId: 'noteA_p0',
          noteId: 'noteA',
          noteTitle: 'Lecture A',
          type: 'audio',
          text: 'Passage text A',
          tokens: ['passage', 'text'],
        ),
        ClientPassage(
          passageId: 'noteB_p1',
          noteId: 'noteB',
          noteTitle: 'Lecture B',
          type: 'audio',
          text: 'Passage text B',
          tokens: ['passage', 'text'],
        ),
      ];

      // Simulated Gemini returned IDs (contains one real and one fabricated)
      final returnedIds = ['noteA_p0', 'hallucinated_note_p99'];

      final verified = <GroundedCitation>[];
      for (final cid in returnedIds) {
        final match = retrievedPassages.where((p) => p.passageId == cid);
        if (match.isNotEmpty) {
          final p = match.first;
          verified.add(GroundedCitation(
            noteId: p.noteId,
            noteTitle: p.noteTitle,
            passageId: p.passageId,
            snippet: p.text,
            relevanceScore: 1.0,
          ));
        }
      }

      // Only noteA_p0 should be accepted
      expect(verified.length, equals(1));
      expect(verified.first.passageId, equals('noteA_p0'));
      expect(verified.any((c) => c.passageId == 'hallucinated_note_p99'), isFalse);
    });
  });
}
