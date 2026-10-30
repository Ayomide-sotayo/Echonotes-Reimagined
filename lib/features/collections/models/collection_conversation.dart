import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a persistent Collection AI conversation session
class CollectionConversation {
  final String id;
  final String title;
  final String collectionId;
  final String collectionName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessage;
  final int messageCount;

  const CollectionConversation({
    required this.id,
    required this.title,
    required this.collectionId,
    required this.collectionName,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
    this.messageCount = 0,
  });

  factory CollectionConversation.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    return CollectionConversation(
      id: doc.id,
      title: data['title'] as String? ?? 'New Conversation',
      collectionId: data['collectionId'] as String? ?? '',
      collectionName: data['collectionName'] as String? ?? 'Collection',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] as String? ?? '',
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'collectionId': collectionId,
      'collectionName': collectionName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastMessage': lastMessage,
      'messageCount': messageCount,
    };
  }
}
