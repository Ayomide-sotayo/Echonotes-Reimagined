import 'package:cloud_firestore/cloud_firestore.dart';

/// A verified citation returned by EchoNotes AI Knowledge Assistant
class GroundedCitation {
  final String noteId;
  final String noteTitle;
  final String passageId;
  final String snippet;
  final double relevanceScore;

  const GroundedCitation({
    required this.noteId,
    required this.noteTitle,
    required this.passageId,
    required this.snippet,
    this.relevanceScore = 0.0,
  });

  factory GroundedCitation.fromMap(Map<String, dynamic> map) {
    return GroundedCitation(
      noteId: map['noteId'] as String? ?? '',
      noteTitle: map['noteTitle'] as String? ?? 'Untitled Note',
      passageId: map['passageId'] as String? ?? '',
      snippet: map['snippet'] as String? ?? '',
      relevanceScore: ((map['relevanceScore'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'noteTitle': noteTitle,
      'passageId': passageId,
      'snippet': snippet,
      'relevanceScore': relevanceScore,
    };
  }
}

/// A message in the Collection AI Workspace conversation
class CollectionChatMessage {
  final String id;
  final String sender; // 'user' or 'assistant'
  final String text;
  final List<GroundedCitation> citations;
  final bool isInsufficientEvidence;
  final DateTime timestamp;
  final bool isPending;

  const CollectionChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.citations = const [],
    this.isInsufficientEvidence = false,
    required this.timestamp,
    this.isPending = false,
  });

  bool get isUser => sender == 'user';
  bool get hasCitations => citations.isNotEmpty;

  /// Cleans raw internal passage IDs (e.g. [91at77V3QYw8ciHOPSDZ_p0] or [passageId_p0])
  /// and any accidental JSON wrappers from the text so students and users see only clean, readable prose.
  static String cleanText(String raw) {
    String text = raw.trim();

    // If raw or truncated JSON was passed, extract the inner answer string
    if (text.startsWith('{') && text.contains('"answer"')) {
      final match = RegExp(r'"answer"\s*:\s*"((?:[^"\\]|\\.)*)', dotAll: true).firstMatch(text);
      if (match != null) {
        text = match.group(1)!
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }
    }

    return text
        .replaceAll(RegExp(r'\s*\[[a-zA-Z0-9_\-]+_p\d+\]'), '')
        .replaceAll(RegExp(r'\s*\[[a-zA-Z0-9_\-]{15,}\]'), '')
        .trim();
  }

  String get displayText => isUser ? text : cleanText(text);

  factory CollectionChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawCitations = data['citations'] as List<dynamic>? ?? [];
    final senderStr = data['sender'] as String? ?? 'assistant';
    final rawText = data['text'] as String? ?? '';

    return CollectionChatMessage(
      id: doc.id,
      sender: senderStr,
      text: senderStr == 'user' ? rawText : cleanText(rawText),
      citations: rawCitations
          .map((c) => GroundedCitation.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      isInsufficientEvidence: data['isInsufficientEvidence'] as bool? ?? false,
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPending: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'citations': citations.map((c) => c.toMap()).toList(),
      'isInsufficientEvidence': isInsufficientEvidence,
      'createdAt': Timestamp.fromDate(timestamp),
    };
  }

  CollectionChatMessage copyWith({
    String? id,
    String? sender,
    String? text,
    List<GroundedCitation>? citations,
    bool? isInsufficientEvidence,
    DateTime? timestamp,
    bool? isPending,
  }) {
    return CollectionChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      citations: citations ?? this.citations,
      isInsufficientEvidence:
          isInsufficientEvidence ?? this.isInsufficientEvidence,
      timestamp: timestamp ?? this.timestamp,
      isPending: isPending ?? this.isPending,
    );
  }
}
