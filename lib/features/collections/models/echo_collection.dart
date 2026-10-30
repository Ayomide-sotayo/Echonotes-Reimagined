import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents a user-owned collection of notes in EchoNotes.
class EchoCollection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String? icon; // Key for icon (e.g., 'folder', 'school', 'work', etc.)
  final int? colorHex; // ARGB integer value (e.g., 0xFF6366F1)
  final DateTime createdAt;
  final DateTime updatedAt;
  final int noteCount;

  const EchoCollection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.icon,
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
    this.noteCount = 0,
  });

  /// Curated color palette adhering to the Hybrid Studio design system
  static const List<int> presetColors = [
    0xFF6366F1, // Studio Indigo / Purple
    0xFF8B5CF6, // Studio Violet
    0xFF06B6D4, // Electric Cyan
    0xFF10B981, // Emerald Green
    0xFFF59E0B, // Amber Warmth
    0xFFEC4899, // Studio Pink
    0xFF3B82F6, // Sky Blue
    0xFF64748B, // Slate Grey
  ];

  /// Curated icons mapped to Material IconData
  static const Map<String, IconData> presetIcons = {
    'folder': Icons.folder_rounded,
    'school': Icons.school_rounded,
    'work': Icons.work_outline_rounded,
    'menu_book': Icons.menu_book_rounded,
    'mic': Icons.mic_rounded,
    'star': Icons.star_rounded,
    'lightbulb': Icons.lightbulb_outline_rounded,
    'bookmark': Icons.bookmark_rounded,
    'favorite': Icons.favorite_rounded,
    'article': Icons.article_rounded,
  };

  /// Resolve color from hex or fallback to Studio Indigo
  Color get color => colorHex != null ? Color(colorHex!) : const Color(0xFF6366F1);

  /// Resolve IconData from icon key or fallback to folder icon
  IconData get iconData {
    if (icon != null && presetIcons.containsKey(icon)) {
      return presetIcons[icon]!;
    }
    return Icons.folder_rounded;
  }

  factory EchoCollection.fromFirestore(DocumentSnapshot doc, [int count = 0]) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return EchoCollection.fromMap(doc.id, data, count);
  }

  factory EchoCollection.fromMap(String id, Map<String, dynamic> data, [int count = 0]) {
    return EchoCollection(
      id: id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? 'Untitled Collection',
      description: data['description'] as String?,
      icon: data['icon'] as String? ?? 'folder',
      colorHex: data['colorHex'] is int
          ? data['colorHex'] as int
          : (data['colorHex'] is String
              ? int.tryParse(data['colorHex'] as String)
              : null),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime
              ? data['createdAt'] as DateTime
              : DateTime.now()),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['updatedAt'] is DateTime
              ? data['updatedAt'] as DateTime
              : DateTime.now()),
      noteCount: count,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (icon != null) 'icon': icon,
      if (colorHex != null) 'colorHex': colorHex,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EchoCollection copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? icon,
    int? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? noteCount,
  }) {
    return EchoCollection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteCount: noteCount ?? this.noteCount,
    );
  }
}
