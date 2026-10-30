import 'package:flutter_test/flutter_test.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';

void main() {
  group('Note Model Tests', () {
    test('Note instantiates correctly with required fields', () {
      final now = DateTime.now();
      final note = Note(
        id: 'test_123',
        userId: 'user_456',
        title: 'Meeting Notes',
        createdAt: now,
        type: 'text',
        summary: 'Discussion on Phase 2 redesign',
      );

      expect(note.id, 'test_123');
      expect(note.userId, 'user_456');
      expect(note.title, 'Meeting Notes');
      expect(note.type, 'text');
      expect(note.mainContent, 'Discussion on Phase 2 redesign');
    });

    test('Note audio mainContent defaults to transcription', () {
      final now = DateTime.now();
      final note = Note(
        id: 'audio_123',
        userId: 'user_456',
        title: 'Voice Memo',
        createdAt: now,
        type: 'audio',
        transcription: 'Audio transcription text',
      );

      expect(note.type, 'audio');
      expect(note.mainContent, 'Audio transcription text');
    });
  });
}
