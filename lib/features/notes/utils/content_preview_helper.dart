import 'dart:math' as math;

/// Result of content preview truncation.
class ContentPreviewResult {
  final String previewText;
  final int totalWords;
  final int previewWords;
  final bool isTruncated;
  final int readingTimeMinutes;

  const ContentPreviewResult({
    required this.previewText,
    required this.totalWords,
    required this.previewWords,
    required this.isTruncated,
    required this.readingTimeMinutes,
  });
}

/// Helper to produce clean word-bounded previews preserving paragraph breaks.
class ContentPreviewHelper {
  /// Counts total words based on non-whitespace sequences.
  static int countWords(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    return RegExp(r'\S+').allMatches(text.trim()).length;
  }

  /// Estimates reading time in minutes assuming average speed of 200 words per minute.
  static int estimateReadingTime(int wordCount) {
    if (wordCount <= 0) return 0;
    return math.max(1, (wordCount / 200).ceil());
  }

  /// Extracts approximately [wordLimit] words while preserving word boundaries
  /// and natural paragraph formatting.
  ///
  /// If the text is shorter than or equal to [wordLimit], it returns all content with
  /// [isTruncated] set to false.
  /// For pathological long unbroken strings (e.g. single words > 1,500 characters),
  /// it caps the preview safely.
  static ContentPreviewResult getPreview(String? text, {required int wordLimit}) {
    if (text == null || text.trim().isEmpty) {
      return const ContentPreviewResult(
        previewText: '',
        totalWords: 0,
        previewWords: 0,
        isTruncated: false,
        readingTimeMinutes: 0,
      );
    }

    final trimmed = text.trim();
    final matches = RegExp(r'\S+').allMatches(trimmed).toList();
    final totalWords = matches.length;

    // Pathological unbroken string check (e.g., 20,000 char unbroken word)
    if (totalWords == 1 && trimmed.length > 1500) {
      return ContentPreviewResult(
        previewText: '${trimmed.substring(0, 1000)}...',
        totalWords: totalWords,
        previewWords: 1,
        isTruncated: true,
        readingTimeMinutes: 1,
      );
    }

    if (totalWords <= wordLimit) {
      return ContentPreviewResult(
        previewText: trimmed,
        totalWords: totalWords,
        previewWords: totalWords,
        isTruncated: false,
        readingTimeMinutes: estimateReadingTime(totalWords),
      );
    }

    // Cut off exactly at the end of the wordLimit-th word
    final cutoffMatch = matches[wordLimit - 1];
    final preview = trimmed.substring(0, cutoffMatch.end).trimRight();

    return ContentPreviewResult(
      previewText: preview,
      totalWords: totalWords,
      previewWords: wordLimit,
      isTruncated: true,
      readingTimeMinutes: estimateReadingTime(totalWords),
    );
  }
}
