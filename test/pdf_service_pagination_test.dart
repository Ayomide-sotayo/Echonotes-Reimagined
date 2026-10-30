import 'dart:convert';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/services/pdf_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test theme using standard Helvetica so tests run fast and deterministically without network
  final testTheme = pw.ThemeData.withFont(
    base: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
    italic: pw.Font.helveticaOblique(),
  );

  group('PDF Export Pagination & Regression Tests', () {
    test('1. 10-word transcript exports cleanly on a single page', () async {
      final words = List.generate(10, (i) => 'word$i').join(' ');
      final note = Note(
        id: 'test-10',
        userId: 'user1',
        title: 'Quick 10 Word Note',
        createdAt: DateTime(2026, 10, 30, 10, 0),
        transcription: words,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(pdfDoc.document.pdfPageList.pages.length, 1);
    });

    test('2. 500-word transcript paginates gracefully', () async {
      final paragraph1 = List.generate(170, (i) => 'alpha$i').join(' ');
      final paragraph2 = List.generate(170, (i) => 'beta$i').join(' ');
      final paragraph3 = List.generate(160, (i) => 'gamma$i').join(' ');
      final fullText = '$paragraph1\n\n$paragraph2\n\n$paragraph3';

      final note = Note(
        id: 'test-500',
        userId: 'user1',
        title: 'Medium Note (500 words)',
        createdAt: DateTime(2026, 10, 30, 11, 0),
        transcription: fullText,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(pdfDoc.document.pdfPageList.pages.length, greaterThanOrEqualTo(1));
    });

    test('3. 2,145-word transcript (Orderliness of Pulpit Presentation) spans across multiple pages without overflow exception', () async {
      // Exactly 2,145 words matching the physical device failure
      final words = List.generate(2145, (i) => 'sermonword$i').join(' ');
      final note = Note(
        id: 'orderliness-pulpit',
        userId: 'pastor1',
        title: 'Orderliness of Pulpit Presentation',
        createdAt: DateTime(2026, 10, 29, 14, 30),
        transcription: words,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      // 2,145 words should span across multiple pages (typically 3 to 5 pages)
      final pageCount = pdfDoc.document.pdfPageList.pages.length;
      expect(pageCount, greaterThan(2));
      print('2,145-word transcript successfully exported to $pageCount pages.');
    });

    test('4. 5,000-word transcript paginates without layout failure', () async {
      final words = List.generate(5000, (i) => 'lecture$i').join(' ');
      final note = Note(
        id: 'test-5000',
        userId: 'user1',
        title: 'Long Lecture Note',
        createdAt: DateTime(2026, 10, 28, 9, 15),
        transcription: words,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      final pageCount = pdfDoc.document.pdfPageList.pages.length;
      expect(pageCount, greaterThan(6));
      print('5,000-word transcript successfully exported to $pageCount pages.');
    });

    test('5. 10,000-word transcript paginates without layout failure', () async {
      final words = List.generate(10000, (i) => 'record$i').join(' ');
      final note = Note(
        id: 'test-10000',
        userId: 'user1',
        title: 'Massive Transcript Note',
        createdAt: DateTime(2026, 10, 27, 8, 0),
        transcription: words,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      final pageCount = pdfDoc.document.pdfPageList.pages.length;
      expect(pageCount, greaterThan(13));
      print('10,000-word transcript successfully exported to $pageCount pages.');
    });

    test('6. Long continuous paragraph without blank lines chunks and paginates safely', () async {
      // 4,000-character paragraph without any newlines
      final longSentence = 'This is a continuous speech-to-text transcript without newline breaks. ';
      final fullText = longSentence * 60; // ~4,260 chars

      final note = Note(
        id: 'test-unbroken',
        userId: 'user1',
        title: 'Unbroken Continuous Transcript',
        createdAt: DateTime.now(),
        transcription: fullText,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(pdfDoc.document.pdfPageList.pages.length, greaterThan(1));
    });

    test('7. Special characters, punctuation, and Unicode normalize safely', () async {
      const specialText =
          'EchoNotes handles smart quotes: \u201Cdouble\u201D & \u2018single\u2019, '
          'em-dash: \u2014, en-dash: \u2013, ellipsis: \u2026, bullets: \u2022 item, '
          'tabs\tand newlines.\nSecond line with (parentheses), [brackets], {braces}, & symbols: 100% #1 @echo!';

      final note = Note(
        id: 'test-special',
        userId: 'user1',
        title: 'Special Chars: \u201COrderliness\u201D \u2014 Pulpit',
        createdAt: DateTime.now(),
        transcription: specialText,
        type: 'audio',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('8. Mixed transcript and AI summary export paginates all sections properly', () async {
      final transcriptWords = List.generate(1500, (i) => 'content$i').join(' ');
      final summaryWords = List.generate(300, (i) => 'summary$i').join(' ');

      final note = Note(
        id: 'test-mixed',
        userId: 'user1',
        title: 'Full Featured Comprehensive Note',
        createdAt: DateTime(2026, 10, 25, 12, 0),
        transcription: transcriptWords,
        aiSummary: summaryWords,
        type: 'audio',
        keywords: ['Pulpit', 'Presentation', 'Order', 'Speaking', 'Structure'],
        actionItems: [
          'Review introduction pacing',
          'Practice transitions between key sermon points',
          'Ensure conclusion stays within allocated time window',
        ],
        sentiment: 'positive',
        translations: {
          'Spanish': 'Resumen completo de la presentacion del pulpito con puntos clave.',
          'French': 'Resume complet de la presentation du pupitre avec les points cles.',
        },
        qaResults: {
          'What was the main topic?': 'The importance of orderliness in pulpit presentations.',
          'What were the recommended steps?': 'Structure the sermon clearly with pacing and review.',
        },
        collectionName: 'Sunday Sermons',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      final pageCount = pdfDoc.document.pdfPageList.pages.length;
      expect(pageCount, greaterThan(2));
      print('Mixed comprehensive note exported to $pageCount pages.');
    });

    test('9. Empty or missing optional content generates valid PDF gracefully', () async {
      final note = Note(
        id: 'test-empty',
        userId: 'user1',
        title: '',
        createdAt: DateTime.now(),
        type: 'text',
      );

      final pdfDoc = await PDFService.generatePDFDocument(note, theme: testTheme);
      final bytes = await pdfDoc.save();

      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(pdfDoc.document.pdfPageList.pages.length, 1);
    });

    test('10. sanitizeFileName creates clean, safe filenames', () {
      expect(
        PDFService.sanitizeFileName('Orderliness of Pulpit Presentation'),
        'EchoNote_Orderliness_of_Pulpit_Presentation.pdf',
      );
      expect(
        PDFService.sanitizeFileName('Note with /:?*"<>| invalid chars!'),
        'EchoNote_Note_with_invalid_chars.pdf',
      );
      expect(
        PDFService.sanitizeFileName('', 'fallback123'),
        'EchoNote_fallback123.pdf',
      );
      expect(
        PDFService.sanitizeFileName(null, 'id-456'),
        'EchoNote_id-456.pdf',
      );
    });

    test('11. splitIntoParagraphs preserves paragraph order and content', () {
      final text = 'First Paragraph\n\nSecond Paragraph with detail\n\nThird Paragraph';
      final paragraphs = PDFService.splitIntoParagraphs(text);

      expect(paragraphs.length, 3);
      expect(paragraphs[0], 'First Paragraph');
      expect(paragraphs[1], 'Second Paragraph with detail');
      expect(paragraphs[2], 'Third Paragraph');
    });
  });
}
