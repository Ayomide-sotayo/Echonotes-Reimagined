import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class PDFService {
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference < 7) {
      return '$difference days ago at ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  static String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  static Future<pw.Font> _loadFont() async {
    // Load a Unicode-compatible font
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      // Fallback to default font if custom font fails
      print('Could not load custom font, using default: $e');
      return pw.Font.helvetica(); // This will still work for basic text
    }
  }

  static Future<pw.Document> _generatePDFDocument(Note note) async {
    final pdf = pw.Document();

    // Load font (optional - comment out if you don't have the font file)
    pw.Font? customFont;
    try {
      customFont = await _loadFont();
    } catch (e) {
      print('Using default font: $e');
    }

    // Create PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'EchoNotes Export',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple,
                      font: customFont,
                    ),
                  ),
                  pw.Text(
                    _formatDate(note.createdAt),
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                      font: customFont,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Title
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.deepPurple50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    note.title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      font: customFont,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${note.type.toUpperCase()} Note',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                      font: customFont,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Content Section
            if (note.mainContent != null) ...[
              pw.Text(
                'Content',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  note.type == 'text'
                      ? (note.summary ?? 'No content')
                      : (note.transcription ?? 'No transcription available'),
                  style: pw.TextStyle(
                    fontSize: 12,
                    lineSpacing: 1.5,
                    font: customFont,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // AI Summary
            if (note.aiSummary != null) ...[
              pw.Text(
                'AI Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  note.aiSummary!,
                  style: pw.TextStyle(
                    fontSize: 12,
                    lineSpacing: 1.5,
                    font: customFont,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Keywords
            if (note.hasKeywords) ...[
              pw.Text(
                'Keywords',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    note.keywords!
                        .map(
                          (keyword) => pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.purple100,
                              borderRadius: pw.BorderRadius.circular(12),
                            ),
                            child: pw.Text(
                              keyword,
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.purple800,
                                font: customFont,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            // Action Items
            if (note.hasActionItems) ...[
              pw.Text(
                'Action Items',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              ...(note.actionItems ?? [])
                  .map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            margin: const pw.EdgeInsets.only(top: 6),
                            width: 4,
                            height: 4,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.orange,
                              shape: pw.BoxShape.circle,
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Text(
                              item,
                              style: pw.TextStyle(
                                fontSize: 12,
                                font: customFont,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              pw.SizedBox(height: 20),
            ],

            // Sentiment
            if (note.hasSentiment) ...[
              pw.Text(
                'Sentiment Analysis',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.pink50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'Overall tone: ${note.sentiment!.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 12, font: customFont),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Translations
            if (note.hasTranslations) ...[
              pw.Text(
                'Translations',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              ...(note.translations?.entries ?? [])
                  .map(
                    (entry) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.purple50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.key.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.purple800,
                              font: customFont,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            entry.value,
                            style: pw.TextStyle(
                              fontSize: 11,
                              lineSpacing: 1.4,
                              font: customFont,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              pw.SizedBox(height: 20),
            ],

            // Q&A Results
            if (note.hasQAResults) ...[
              pw.Text(
                'Questions & Answers',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: customFont,
                ),
              ),
              pw.SizedBox(height: 8),
              ...(note.qaResults?.entries ?? [])
                  .map(
                    (entry) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 16),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue100,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Text(
                              'Q: ${entry.key}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                font: customFont,
                              ),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Text(
                              'A: ${entry.value}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                lineSpacing: 1.4,
                                font: customFont,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],

            // Footer
            pw.SizedBox(height: 40),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Generated by EchoNotes - ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  font: customFont,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  // Method to save PDF and share it
  static Future<void> generateAndSharePDF(Note note) async {
    try {
      final pdf = await _generatePDFDocument(note);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/echonote_${note.id}.pdf');

      // Save PDF to temporary file
      await file.writeAsBytes(await pdf.save());

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'EchoNote: ${note.title}',
        subject: 'EchoNote Export',
      );
    } catch (e) {
      print('Error generating and sharing PDF: $e');
      rethrow;
    }
  }

  // Single method for PDF export via sharing
  static Future<void> generateAndExportPDF(Note note) async {
    await generateAndSharePDF(note);
  }
}
