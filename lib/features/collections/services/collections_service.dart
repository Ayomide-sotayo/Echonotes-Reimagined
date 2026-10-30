import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echonotes/features/collections/models/echo_collection.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';

/// Service managing EchoNotes Collections in Firestore.
/// Enforces user-ownership, preserves notes on collection deletion,
/// and powers the Hybrid Studio Collections UI.
class CollectionsService {
  static final CollectionsService _instance = CollectionsService._internal();
  factory CollectionsService() => _instance;
  CollectionsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collectionsRef =>
      _firestore.collection('collections');

  CollectionReference<Map<String, dynamic>> get _notesRef =>
      _firestore.collection('notes');

  /// Stream of user collections with real-time note counts
  Stream<List<EchoCollection>> getCollectionsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _collectionsRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((collectionsSnap) async {
          final collections =
              collectionsSnap.docs
                  .map((doc) => EchoCollection.fromFirestore(doc))
                  .toList();

          // Sort by updatedAt descending (client-side fallback to avoid composite index hurdles)
          collections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          // Fetch note counts for each collection
          final countsSnap =
              await _notesRef.where('userId', isEqualTo: userId).get();

          final countMap = <String, int>{};
          for (final noteDoc in countsSnap.docs) {
            final colId = noteDoc.data()['collectionId'] as String?;
            if (colId != null && colId.isNotEmpty) {
              countMap[colId] = (countMap[colId] ?? 0) + 1;
            }
          }

          return collections.map((col) {
            final count = countMap[col.id] ?? 0;
            return col.copyWith(noteCount: count);
          }).toList();
        });
  }

  /// Get total count of unfiled notes for a user
  Stream<int> getUnfiledNoteCountStream(String userId) {
    if (userId.isEmpty) return Stream.value(0);

    return _notesRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          int unfiledCount = 0;
          for (final doc in snapshot.docs) {
            final colId = doc.data()['collectionId'] as String?;
            if (colId == null || colId.isEmpty) {
              unfiledCount++;
            }
          }
          return unfiledCount;
        });
  }

  /// Stream of notes filtered by collection (or unfiled notes when collectionId is null)
  Stream<List<Note>> getNotesForCollectionStream(
    String userId, {
    String? collectionId,
  }) {
    if (userId.isEmpty) return Stream.value([]);

    return _notesRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notes =
              snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList();

          // Sort by createdAt descending
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (collectionId == null || collectionId.isEmpty) {
            // Return unfiled notes
            return notes.where((n) => n.isUnfiled).toList();
          } else {
            // Return notes belonging to this specific collection
            return notes.where((n) => n.collectionId == collectionId).toList();
          }
        });
  }

  /// Create a new collection
  Future<EchoCollection> createCollection({
    required String userId,
    required String name,
    String? description,
    String? icon,
    int? colorHex,
  }) async {
    final now = DateTime.now();
    final data = {
      'userId': userId,
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'icon': icon ?? 'folder',
      'colorHex': colorHex ?? EchoCollection.presetColors.first,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await _collectionsRef.add(data);
    final docSnap = await docRef.get();
    return EchoCollection.fromFirestore(docSnap, 0);
  }

  /// Update collection metadata (name, description, icon, color)
  Future<void> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    String? icon,
    int? colorHex,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (name != null && name.trim().isNotEmpty) {
      updates['name'] = name.trim();
    }
    if (description != null) {
      updates['description'] = description.trim();
    }
    if (icon != null) {
      updates['icon'] = icon;
    }
    if (colorHex != null) {
      updates['colorHex'] = colorHex;
    }

    await _collectionsRef.doc(collectionId).update(updates);

    // If name was updated, update denormalized collectionName in notes
    if (name != null && name.trim().isNotEmpty) {
      final matchingNotes =
          await _notesRef.where('collectionId', isEqualTo: collectionId).get();
      if (matchingNotes.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in matchingNotes.docs) {
          batch.update(doc.reference, {'collectionName': name.trim()});
        }
        await batch.commit();
      }
    }
  }

  /// Delete a collection.
  /// IMPORTANT: Deleting a collection NEVER deletes its notes!
  /// All associated notes have their collection link removed and become Unfiled.
  Future<void> deleteCollection({
    required String collectionId,
    required String userId,
  }) async {
    // 1. Fetch all notes belonging to this collection
    final matchingNotes =
        await _notesRef
            .where('userId', isEqualTo: userId)
            .where('collectionId', isEqualTo: collectionId)
            .get();

    final batch = _firestore.batch();

    // 2. Unlink all notes (set collectionId and collectionName to delete)
    for (final doc in matchingNotes.docs) {
      batch.update(doc.reference, {
        'collectionId': FieldValue.delete(),
        'collectionName': FieldValue.delete(),
      });
    }

    // 3. Delete the collection document
    batch.delete(_collectionsRef.doc(collectionId));

    // 4. Commit atomically
    await batch.commit();
  }

  /// Move a note to a collection or remove it (set to unfiled if collectionId is null)
  Future<void> moveNoteToCollection({
    required String noteId,
    String? collectionId,
    String? collectionName,
  }) async {
    if (collectionId != null && collectionId.isNotEmpty) {
      await _notesRef.doc(noteId).update({
        'collectionId': collectionId,
        'collectionName': collectionName ?? '',
      });
    } else {
      await _notesRef.doc(noteId).update({
        'collectionId': FieldValue.delete(),
        'collectionName': FieldValue.delete(),
      });
    }
  }

  /// Remove a note from its current collection (moves to Unfiled)
  Future<void> removeNoteFromCollection(String noteId) async {
    await moveNoteToCollection(noteId: noteId, collectionId: null);
  }
}
