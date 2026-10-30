import 'dart:io';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PDFService {
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0 && now.day == date.day) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference == 1 || (difference == 0 && now.day != date.day)) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference < 7 && difference > 0) {
      return '$difference days ago at ${_formatTime(date)}';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month/${date.year} at ${_formatTime(date)}';
    }
  }

  static String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  /// Sanitizes text for PDF rendering by normalizing smart quotes, dashes,
  /// ellipsis, and stripping unprintable control characters.
  static String sanitizeText(String text, {bool fallbackMode = false}) {
    if (text.isEmpty) return text;

    var cleaned = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00A0', ' ') // non-breaking space
        .replaceAll('\u2018', "'") // left single quote
        .replaceAll('\u2019', "'") // right single quote
        .replaceAll('\u201C', '"') // left double quote
        .replaceAll('\u201D', '"') // right double quote
        .replaceAll('\u2014', ' - ') // em-dash
        .replaceAll('\u2013', '-') // en-dash
        .replaceAll('\u2026', '...') // ellipsis
        .replaceAll('\u2022', '* ') // bullet point
        .replaceAll('\u25CF', '* ') // black circle bullet
        .replaceAll('\t', '    ');

    if (fallbackMode) {
      cleaned = cleaned.replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
    } else {
      cleaned = cleaned.replaceAll(
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
        '',
      );
    }

    return cleaned;
  }

  /// Splits text into page-friendly paragraph chunks.
  /// If a single continuous paragraph exceeds [maxChunkChars], it breaks
  /// along sentence or word boundaries to prevent layout exceptions.
  static List<String> splitIntoParagraphs(
    String rawText, {
    int maxChunkChars = 1200,
  }) {
    if (rawText.trim().isEmpty) return [];

    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');
    final List<String> paragraphs = [];

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length <= maxChunkChars) {
        paragraphs.add(trimmed);
      } else {
        var remaining = trimmed;
        while (remaining.length > maxChunkChars) {
          int splitIndex = -1;
          final lookaroundStart = (maxChunkChars * 0.6).round();
          final searchSlice = remaining.substring(
            lookaroundStart,
            maxChunkChars,
          );

          final sentenceMatches = RegExp(
            r'[\.\?\!]\s+',
          ).allMatches(searchSlice);
          if (sentenceMatches.isNotEmpty) {
            splitIndex = lookaroundStart + sentenceMatches.last.end;
          } else {
            final spaceIndex = remaining.lastIndexOf(' ', maxChunkChars);
            if (spaceIndex > lookaroundStart) {
              splitIndex = spaceIndex + 1;
            } else {
              splitIndex = maxChunkChars;
            }
          }

          final chunk = remaining.substring(0, splitIndex).trim();
          if (chunk.isNotEmpty) {
            paragraphs.add(chunk);
          }
          remaining = remaining.substring(splitIndex).trim();
        }
        if (remaining.isNotEmpty) {
          paragraphs.add(remaining);
        }
      }
    }

    return paragraphs;
  }

  /// Generates a clean, safe filename from the note title.
  static String sanitizeFileName(
    String? title, [
    String fallbackId = 'export',
  ]) {
    final cleanFallback = fallbackId.replaceAll(RegExp(r'[^\w\-]'), '');
    final fallback = cleanFallback.isNotEmpty ? cleanFallback : 'export';

    if (title == null || title.trim().isEmpty) {
      return 'EchoNote_$fallback.pdf';
    }

    var clean = title.trim().replaceAll(RegExp(r'[^\w\s\-]'), '');
    clean = clean.replaceAll(RegExp(r'\s+'), '_');

    if (clean.length > 50) {
      clean = clean.substring(0, 50).trim();
    }

    if (clean.isEmpty) {
      return 'EchoNote_$fallback.pdf';
    }

    return 'EchoNote_$clean.pdf';
  }

  /// Loads Google Fonts (Roboto) with a fallback to standard Helvetica.
  static Future<pw.ThemeData> _loadTheme() async {
    try {
      final baseFont = await PdfGoogleFonts.robotoRegular().timeout(
        const Duration(seconds: 3),
      );
      final boldFont = await PdfGoogleFonts.robotoBold().timeout(
        const Duration(seconds: 3),
      );
      final italicFont = await PdfGoogleFonts.robotoItalic().timeout(
        const Duration(seconds: 3),
      );
      return pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
        italic: italicFont,
      );
    } catch (e) {
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      );
    }
  }

  /// Generates a paginated [pw.Document] for the provided [Note].
  /// Uses [pw.MultiPage] and [pw.Paragraph] spanning widgets so that short
  /// and long transcripts, summaries, and notes paginate cleanly without
  /// overflowing the page height.
  static Future<pw.Document> generatePDFDocument(
    Note note, {
    pw.ThemeData? theme,
  }) async {
    final pdf = pw.Document();
    final docTheme = theme ?? await _loadTheme();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        theme: docTheme,
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.SizedBox.shrink();
          }
          final headerTitle =
              note.title.isNotEmpty ? note.title : 'EchoNotes Export';
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    sanitizeText(headerTitle),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                    maxLines: 1,
                  ),
                ),
                pw.Text(
                  'EchoNotes',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepPurple700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Exported with EchoNotes',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];

          // 1. Top Branding Header (Page 1)
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EchoNotes',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepPurple700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Voice & Text Note Intelligence',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  _formatDate(note.createdAt),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 14));

          // 2. Note Title Card (Compact & non-overflowing)
          final displayTitle =
              note.title.isNotEmpty ? note.title : 'Untitled Note';
          widgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.deepPurple50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(
                  color: PdfColors.deepPurple100,
                  width: 0.8,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    sanitizeText(displayTitle),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.deepPurple700,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '${note.type.toUpperCase()} NOTE',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      if (note.collectionName != null &&
                          note.collectionName!.isNotEmpty) ...[
                        pw.SizedBox(width: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            sanitizeText(note.collectionName!),
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );

          widgets.add(pw.SizedBox(height: 16));

          // 3. AI Summary (Spans across pages via pw.Paragraph)
          if (note.aiSummary != null && note.aiSummary!.trim().isNotEmpty) {
            widgets.add(
              pw.Text(
                'AI Summary',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            final summaryParas = splitIntoParagraphs(
              sanitizeText(note.aiSummary!),
            );
            for (final para in summaryParas) {
              widgets.add(
                pw.Paragraph(
                  text: para,
                  style: const pw.TextStyle(
                    fontSize: 10.5,
                    lineSpacing: 1.45,
                    color: PdfColors.blueGrey900,
                  ),
                  margin: const pw.EdgeInsets.only(bottom: 6),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 14));
          }

          // 4. Main Content / Transcript (Spans across pages via pw.Paragraph)
          final mainText =
              note.type == 'text'
                  ? (note.summary ?? note.mainContent)
                  : (note.transcription ?? note.mainContent);

          if (mainText != null && mainText.trim().isNotEmpty) {
            final sectionTitle = note.type == 'text' ? 'Content' : 'Transcript';
            widgets.add(
              pw.Text(
                sectionTitle,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            final contentParas = splitIntoParagraphs(sanitizeText(mainText));
            for (final para in contentParas) {
              widgets.add(
                pw.Paragraph(
                  text: para,
                  style: const pw.TextStyle(
                    fontSize: 10.5,
                    lineSpacing: 1.45,
                    color: PdfColors.grey900,
                  ),
                  margin: const pw.EdgeInsets.only(bottom: 6),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 14));
          }

          // 5. Keywords
          if (note.hasKeywords && note.keywords!.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Keywords',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    note.keywords!
                        .map(
                          (keyword) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.purple100,
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            child: pw.Text(
                              sanitizeText(keyword),
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.purple900,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          // 6. Action Items
          if (note.hasActionItems && note.actionItems!.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Action Items',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            for (final item in note.actionItems!) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 5, right: 8),
                        width: 4,
                        height: 4,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.deepPurple,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          sanitizeText(item),
                          style: const pw.TextStyle(
                            fontSize: 10,
                            lineSpacing: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 14));
          }

          // 7. Sentiment Analysis
          if (note.hasSentiment && note.sentiment!.trim().isNotEmpty) {
            widgets.add(
              pw.Text(
                'Sentiment Analysis',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.pink50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.pink200, width: 0.5),
                ),
                child: pw.Text(
                  'Tone: ${sanitizeText(note.sentiment!).toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.pink900,
                  ),
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 14));
          }

          // 8. Translations
          if (note.hasTranslations && note.translations!.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Translations',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            for (final entry in note.translations!.entries) {
              widgets.add(
                pw.Text(
                  sanitizeText(entry.key).toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.purple800,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 3));
              final transParas = splitIntoParagraphs(sanitizeText(entry.value));
              for (final p in transParas) {
                widgets.add(
                  pw.Paragraph(
                    text: p,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4),
                    margin: const pw.EdgeInsets.only(bottom: 6),
                  ),
                );
              }
              widgets.add(pw.SizedBox(height: 6));
            }
            widgets.add(pw.SizedBox(height: 10));
          }

          // 9. Q&A Results
          if (note.hasQAResults && note.qaResults!.isNotEmpty) {
            widgets.add(
              pw.Text(
                'Questions & Answers',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.deepPurple800,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
            for (final entry in note.qaResults!.entries) {
              widgets.add(
                pw.Paragraph(
                  text: 'Q: ${sanitizeText(entry.key)}',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                  margin: const pw.EdgeInsets.only(bottom: 3),
                ),
              );
              final ansParas = splitIntoParagraphs(sanitizeText(entry.value));
              for (final a in ansParas) {
                widgets.add(
                  pw.Paragraph(
                    text: 'A: $a',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      lineSpacing: 1.35,
                      color: PdfColors.grey800,
                    ),
                    margin: const pw.EdgeInsets.only(bottom: 6),
                  ),
                );
              }
              widgets.add(pw.SizedBox(height: 6));
            }
          }

          return widgets;
        },
      ),
    );

    return pdf;
  }

  /// Exports the note as a PDF and triggers the platform share dialog.
  /// Generates a meaningful filename without exposing private transcripts in logs.
  static Future<void> generateAndSharePDF(Note note) async {
    try {
      final pdf = await generatePDFDocument(note);

      final directory = await getTemporaryDirectory();
      final fileName = sanitizeFileName(note.title, note.id);
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      final displayTitle =
          note.title.isNotEmpty ? note.title : 'EchoNote Export';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
        text: 'EchoNote: $displayTitle',
        subject: displayTitle,
      );
    } catch (e) {
      print('Error generating or sharing PDF: $e');
      rethrow;
    }
  }

  /// Legacy alias for [generateAndSharePDF].
  static Future<void> generateAndExportPDF(Note note) async {
    await generateAndSharePDF(note);
  }
}
