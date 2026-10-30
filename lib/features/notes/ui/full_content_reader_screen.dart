import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:echonotes/core/theme.dart';
import 'package:echonotes/features/notes/utils/content_preview_helper.dart';

/// The type of content being read in FullContentReaderScreen.
enum ReaderContentType {
  transcript,
  textNote,
  aiSummary;

  String get label {
    switch (this) {
      case ReaderContentType.transcript:
        return 'Full Transcript';
      case ReaderContentType.textNote:
        return 'Full Note';
      case ReaderContentType.aiSummary:
        return 'Executive Summary';
    }
  }

  IconData get icon {
    switch (this) {
      case ReaderContentType.transcript:
        return Icons.transcribe_rounded;
      case ReaderContentType.textNote:
        return Icons.article_outlined;
      case ReaderContentType.aiSummary:
        return Icons.auto_awesome_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case ReaderContentType.transcript:
        return const Color(0xFF6366F1); // Indigo
      case ReaderContentType.textNote:
        return const Color(0xFF3B82F6); // Blue
      case ReaderContentType.aiSummary:
        return const Color(0xFF8B5CF6); // Purple
    }
  }
}

/// Arguments model for FullContentReaderScreen.
class FullContentReaderArgs {
  final String noteTitle;
  final ReaderContentType contentType;
  final String fullText;

  const FullContentReaderArgs({
    required this.noteTitle,
    required this.contentType,
    required this.fullText,
  });
}

/// A dedicated, distraction-free reading screen for long transcripts, notes, and AI summaries.
///
/// Features:
/// - Virtualized paragraph rendering via [ListView.builder] for smooth scrolling up to 20,000+ words
/// - Selectable text with full clipboard copy action
/// - Clean typography with generous line-height
/// - System text scaling & dark mode support
class FullContentReaderScreen extends StatefulWidget {
  final String noteTitle;
  final ReaderContentType contentType;
  final String fullText;

  const FullContentReaderScreen({
    super.key,
    required this.noteTitle,
    required this.contentType,
    required this.fullText,
  });

  @override
  State<FullContentReaderScreen> createState() => _FullContentReaderScreenState();
}

class _FullContentReaderScreenState extends State<FullContentReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  late final List<String> _paragraphs;
  late final int _wordCount;
  late final int _readingTimeMinutes;

  @override
  void initState() {
    super.initState();
    _wordCount = ContentPreviewHelper.countWords(widget.fullText);
    _readingTimeMinutes = ContentPreviewHelper.estimateReadingTime(_wordCount);
    _paragraphs = _prepareParagraphs(widget.fullText);
  }

  /// Splits content into virtualized paragraphs for high-performance rendering.
  /// If a single paragraph is excessively long (> 1,200 chars), it splits on sentence boundaries
  /// to keep frame rendering lightweight even for 20,000+ words.
  List<String> _prepareParagraphs(String text) {
    if (text.trim().isEmpty) return ['No content to display.'];

    final normalized = text.replaceAll(r'\n', '\n').replaceAll(r'\r', '');
    final rawParagraphs = normalized.trim().split(RegExp(r'\n\s*\n|\n'));
    final List<String> result = [];

    for (final p in rawParagraphs) {
      final trimmedP = p.trim();
      if (trimmedP.isEmpty) continue;

      if (trimmedP.length > 1500) {
        // Break large single blocks into sentence chunks to preserve rendering speed
        final sentences = trimmedP.split(RegExp(r'(?<=[.!?])\s+'));
        final buffer = StringBuffer();
        for (final s in sentences) {
          if (buffer.length + s.length > 1000 && buffer.isNotEmpty) {
            result.add(buffer.toString().trim());
            buffer.clear();
          }
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(s);
        }
        if (buffer.isNotEmpty) {
          result.add(buffer.toString().trim());
        }
      } else {
        result.add(trimmedP);
      }
    }

    return result.isEmpty ? [text.trim()] : result;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              '${widget.contentType.label} copied to clipboard',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.contentType.accentColor;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to note',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.noteTitle.isEmpty ? 'Untitled Note' : widget.noteTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                Icon(widget.contentType.icon, size: 12, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  widget.contentType.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
            tooltip: 'Copy all text',
            onPressed: _copyToClipboard,
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata Banner (Word count & Reading time)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.contentType.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.format_size_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_wordCount words',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '~$_readingTimeMinutes min read',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Selectable virtualized reader content
            Expanded(
              child: SelectionArea(
                child: Scrollbar(
                  controller: _scrollController,
                  thickness: 5,
                  radius: const Radius.circular(8),
                  interactive: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    itemCount: _paragraphs.length,
                    itemBuilder: (context, index) {
                      final paragraph = _paragraphs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          paragraph,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            height: 1.72,
                            letterSpacing: 0.1,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
