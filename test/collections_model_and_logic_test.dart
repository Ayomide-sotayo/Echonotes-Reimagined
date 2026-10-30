import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';

void main() {
  group('EchoCollection Model Tests', () {
    test('creates EchoCollection with defaults and converts to/from Map', () {
      final now = DateTime.now();
      final collection = EchoCollection(
        id: 'col_123',
        userId: 'user_abc',
        name: 'Theology School',
        description: 'Semester 1 lectures and reading notes',
        colorHex: 0xFF5B30DE,
        icon: 'school',
        createdAt: now,
        updatedAt: now,
        noteCount: 5,
      );

      expect(collection.id, 'col_123');
      expect(collection.userId, 'user_abc');
      expect(collection.name, 'Theology School');
      expect(collection.description, 'Semester 1 lectures and reading notes');
      expect(collection.color, const Color(0xFF5B30DE));
      expect(collection.iconData, Icons.school_rounded);
      expect(collection.noteCount, 5);

      final map = collection.toFirestore();
      expect(map['userId'], 'user_abc');
      expect(map['name'], 'Theology School');
      expect(map['description'], 'Semester 1 lectures and reading notes');
      expect(map['colorHex'], 0xFF5B30DE);
      expect(map['icon'], 'school');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());

      // Test fromMap parsing
      final restored = EchoCollection.fromMap('col_123', {
        'userId': 'user_abc',
        'name': 'Theology School',
        'description': 'Semester 1 lectures and reading notes',
        'colorHex': 0xFF5B30DE,
        'icon': 'school',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'noteCount': 5,
      }, 5);

      expect(restored.id, 'col_123');
      expect(restored.name, 'Theology School');
      expect(restored.userId, 'user_abc');
      expect(restored.noteCount, 5);
      expect(restored.colorHex, 0xFF5B30DE);
      expect(restored.icon, 'school');
    });

    test('copyWith updates fields correctly', () {
      final now = DateTime.now();
      final collection = EchoCollection(
        id: 'col_1',
        userId: 'user_1',
        name: 'Work Meetings',
        createdAt: now,
        updatedAt: now,
      );

      final updated = collection.copyWith(
        name: 'Executive Work Meetings',
        noteCount: 12,
        description: 'New Description',
      );

      expect(updated.id, 'col_1');
      expect(updated.name, 'Executive Work Meetings');
      expect(updated.noteCount, 12);
      expect(updated.description, 'New Description');
      expect(updated.userId, 'user_1');
    });

    test('EchoCollection provides curated preset colors and icons', () {
      expect(EchoCollection.presetColors.length, greaterThanOrEqualTo(8));
      expect(EchoCollection.presetIcons.length, greaterThanOrEqualTo(8));
      expect(EchoCollection.presetColors.contains(0xFF6366F1), isTrue);
    });
  });

  group('Note Model Collection Integration Tests', () {
    test('Note is unfiled by default when collectionId is null or empty', () {
      final noteUnfiled = Note(
        id: 'note_1',
        userId: 'user_123',
        title: 'Random Idea',
        type: 'text',
        createdAt: DateTime.now(),
      );

      expect(noteUnfiled.collectionId, isNull);
      expect(noteUnfiled.collectionName, isNull);
      expect(noteUnfiled.isUnfiled, isTrue);

      final noteWithEmptyCol = noteUnfiled.copyWith(
        collectionId: '',
        collectionName: '',
      );
      expect(noteWithEmptyCol.isUnfiled, isTrue);
    });

    test('Note is filed when collectionId is provided', () {
      final note = Note(
        id: 'note_2',
        userId: 'user_123',
        title: 'Hermeneutics Lecture 1',
        type: 'audio',
        createdAt: DateTime.now(),
        collectionId: 'col_theology_123',
        collectionName: 'Theology School',
      );

      expect(note.collectionId, 'col_theology_123');
      expect(note.collectionName, 'Theology School');
      expect(note.isUnfiled, isFalse);

      final map = note.toFirestore();
      expect(map['collectionId'], 'col_theology_123');
      expect(map['collectionName'], 'Theology School');
    });

    test('Note copyWith allows moving and clearing collection safely', () {
      final note = Note(
        id: 'note_3',
        userId: 'user_123',
        title: 'Budget Q3',
        type: 'text',
        createdAt: DateTime.now(),
        collectionId: 'col_work',
        collectionName: 'Work Meetings',
      );

      // Move note
      final moved = note.copyWith(
        collectionId: 'col_personal',
        collectionName: 'Personal Study',
      );
      expect(moved.collectionId, 'col_personal');
      expect(moved.collectionName, 'Personal Study');
      expect(moved.isUnfiled, isFalse);

      // Unfile / Remove note from collection
      final unfiled = moved.copyWith(clearCollection: true);
      expect(unfiled.collectionId, isNull);
      expect(unfiled.collectionName, isNull);
      expect(unfiled.isUnfiled, isTrue);
    });
  });
}
