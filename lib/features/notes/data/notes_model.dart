import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final String? summary; // For text notes
  final String? audioUrl; // For audio notes
  final String? transcription; // For audio note transcription
  final String? aiSummary; // For AI-generated summary
  final String type;

  // 🆕 New AI-powered fields
  final List<String>? keywords; // Auto-generated keywords/tags
  final List<String>? actionItems; // Extracted action items
  final String? sentiment; // Sentiment analysis result
  final Map<String, String>?
  translations; // Translations (language code -> text)
  final Map<String, String>? qaResults; // Q&A results (question -> answer)

  // 🆕 Phase 7 Collection fields
  final String? collectionId;
  final String? collectionName;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    this.summary,
    this.audioUrl,
    this.transcription,
    this.aiSummary,
    required this.type,
    // New fields
    this.keywords,
    this.actionItems,
    this.sentiment,
    this.translations,
    this.qaResults,
    // Phase 7 Collections
    this.collectionId,
    this.collectionName,
  });

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Note(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      summary: data['summary'],
      audioUrl: data['audioUrl'],
      transcription: data['transcription'],
      aiSummary: data['aiSummary'],
      type: data['type'] ?? 'text',
      // New fields with safe parsing
      keywords:
          data['keywords'] != null ? List<String>.from(data['keywords']) : null,
      actionItems:
          data['actionItems'] != null
              ? List<String>.from(data['actionItems'])
              : null,
      sentiment: data['sentiment'],
      translations:
          data['translations'] != null
              ? Map<String, String>.from(data['translations'])
              : null,
      qaResults:
          data['qaResults'] != null
              ? Map<String, String>.from(data['qaResults'])
              : null,
      // Phase 7 Collections
      collectionId: data['collectionId'] as String?,
      collectionName: data['collectionName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      if (summary != null) 'summary': summary,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (transcription != null) 'transcription': transcription,
      if (aiSummary != null) 'aiSummary': aiSummary,
      'type': type,
      // New fields
      if (keywords != null) 'keywords': keywords,
      if (actionItems != null) 'actionItems': actionItems,
      if (sentiment != null) 'sentiment': sentiment,
      if (translations != null) 'translations': translations,
      if (qaResults != null) 'qaResults': qaResults,
      // Phase 7 Collections
      if (collectionId != null && collectionId!.isNotEmpty)
        'collectionId': collectionId,
      if (collectionName != null && collectionName!.isNotEmpty)
        'collectionName': collectionName,
    };
  }

  // 🆕 Helper methods for better UX
  bool get hasKeywords => keywords != null && keywords!.isNotEmpty;
  bool get hasActionItems => actionItems != null && actionItems!.isNotEmpty;
  bool get hasSentiment => sentiment != null;
  bool get hasTranslations => translations != null && translations!.isNotEmpty;
  bool get hasQAResults => qaResults != null && qaResults!.isNotEmpty;
  bool get isUnfiled => collectionId == null || collectionId!.isEmpty;

  // Get main content for analysis (transcription or summary)
  String? get mainContent => transcription ?? summary;

  // Get sentiment emoji
  String get sentimentEmoji {
    if (sentiment == null) return '😐';
    switch (sentiment!.toLowerCase()) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😔';
      default:
        return '😐';
    }
  }

  // Copy method for updates
  Note copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? createdAt,
    String? summary,
    String? audioUrl,
    String? transcription,
    String? aiSummary,
    String? type,
    List<String>? keywords,
    List<String>? actionItems,
    String? sentiment,
    Map<String, String>? translations,
    Map<String, String>? qaResults,
    String? collectionId,
    String? collectionName,
    bool clearCollection = false,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      summary: summary ?? this.summary,
      audioUrl: audioUrl ?? this.audioUrl,
      transcription: transcription ?? this.transcription,
      aiSummary: aiSummary ?? this.aiSummary,
      type: type ?? this.type,
      keywords: keywords ?? this.keywords,
      actionItems: actionItems ?? this.actionItems,
      sentiment: sentiment ?? this.sentiment,
      translations: translations ?? this.translations,
      qaResults: qaResults ?? this.qaResults,
      collectionId: clearCollection ? null : (collectionId ?? this.collectionId),
      collectionName:
          clearCollection ? null : (collectionName ?? this.collectionName),
    );
  }
}
