import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echonotes/features/notes/ui/full_content_reader_screen.dart';
import 'package:echonotes/features/notes/utils/content_preview_helper.dart';

void main() {
  group('ContentPreviewHelper Robustness & Boundary Tests', () {
    test('Empty and null content returns zero words and empty preview', () {
      final nullResult = ContentPreviewHelper.getPreview(null, wordLimit: 120);
      expect(nullResult.totalWords, 0);
      expect(nullResult.previewWords, 0);
      expect(nullResult.isTruncated, false);
      expect(nullResult.previewText, '');

      final emptyResult = ContentPreviewHelper.getPreview('', wordLimit: 120);
      expect(emptyResult.totalWords, 0);
      expect(emptyResult.isTruncated, false);
      expect(emptyResult.previewText, '');

      final whitespaceResult = ContentPreviewHelper.getPreview('   \n\t  ', wordLimit: 80);
      expect(whitespaceResult.totalWords, 0);
      expect(whitespaceResult.isTruncated, false);
    });

    test('Short text of fewer than 50 words does not truncate', () {
      final text = List.generate(40, (i) => 'word$i').join(' ');
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 120);

      expect(result.totalWords, 40);
      expect(result.previewWords, 40);
      expect(result.isTruncated, false);
      expect(result.previewText, text);
    });

    test('Exactly the preview threshold (120 words) does not truncate', () {
      final text = List.generate(120, (i) => 'word$i').join(' ');
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 120);

      expect(result.totalWords, 120);
      expect(result.previewWords, 120);
      expect(result.isTruncated, false);
      expect(result.previewText, text);
    });

    test('121 words triggers truncation at exactly 120 words', () {
      final words = List.generate(121, (i) => 'word$i');
      final text = words.join(' ');
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 120);

      expect(result.totalWords, 121);
      expect(result.previewWords, 120);
      expect(result.isTruncated, true);
      expect(result.previewText, words.take(120).join(' '));
    });

    test('Summary threshold (80 words) behaves identically for summary limit', () {
      final words = List.generate(150, (i) => 'term$i');
      final text = words.join(' ');
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 80);

      expect(result.totalWords, 150);
      expect(result.previewWords, 80);
      expect(result.isTruncated, true);
      expect(result.previewText, words.take(80).join(' '));
    });

    test('500-word transcript correctly computes preview, word count and reading time', () {
      final words = List.generate(500, (i) => 'lecture$i');
      final text = words.join(' ');
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 120);

      expect(result.totalWords, 500);
      expect(result.previewWords, 120);
      expect(result.isTruncated, true);
      expect(result.readingTimeMinutes, 3); // 500 / 200 = 2.5 => 3 min
    });

    test('5,000-word transcript handles large document boundary smoothly', () {
      final words = List.generate(5000, (i) => 'theology$i');
      final text = words.join(' ');
      final stopwatch = Stopwatch()..start();
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 120);
      stopwatch.stop();

      expect(result.totalWords, 5000);
      expect(result.previewWords, 120);
      expect(result.isTruncated, true);
      expect(result.readingTimeMinutes, 25); // 5000 / 200 = 25 min
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Fast calculation
    });

    test('20,000-word transcript performance is sub-50ms', () {
      final words = List.generate(20000, (i) => 'sermon$i');
      final text = words.join(' ');
      final stopwatch = Stopwatch()..start();
      final result = ContentPreviewHelper.getPreview(text, wordLimit: 120);
      stopwatch.stop();

      expect(result.totalWords, 20000);
      expect(result.previewWords, 120);
      expect(result.isTruncated, true);
      expect(result.readingTimeMinutes, 100);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('Long unbroken text does not throw and caps safely', () {
      final unbroken = 'a' * 10000;
      final result = ContentPreviewHelper.getPreview(unbroken, wordLimit: 120);

      expect(result.totalWords, 1);
      expect(result.isTruncated, true);
      expect(result.previewText.length, lessThanOrEqualTo(1004));
      expect(result.previewText.endsWith('...'), true);
    });

    test('Multiple paragraphs preserve natural line breaks in preview', () {
      const paragraphText = 'Paragraph one begins here with some introduction.\n\n'
          'Paragraph two continues the theological discussion with additional depth.\n\n'
          'Paragraph three concludes with practical lessons.';
      final result = ContentPreviewHelper.getPreview(paragraphText, wordLimit: 120);

      expect(result.isTruncated, false);
      expect(result.previewText.contains('\n\n'), true);
      expect(result.totalWords, ContentPreviewHelper.countWords(paragraphText));
    });

    test('Emojis, special characters, and Unicode are counted accurately', () {
      const unicodeText = 'Hello 👋! Ancient honey 🍯 was found in Pharaoh’s tomb. '
          'Greek: θεολογία & Hebrew: תורה with €100 and 100% pure nectar.';
      final result = ContentPreviewHelper.getPreview(unicodeText, wordLimit: 120);

      expect(result.totalWords, ContentPreviewHelper.countWords(unicodeText));
      expect(result.isTruncated, false);
      expect(result.previewText, unicodeText);
    });
  });

  group('FullContentReaderScreen Widget Tests', () {
    testWidgets('Renders Transcript Reader with word count and metadata banner', (tester) async {
      final sampleTranscript = List.generate(200, (i) => 'lecture_word_$i').join(' ');

      await tester.pumpWidget(
        MaterialApp(
          home: FullContentReaderScreen(
            noteTitle: 'Theology 101 Lecture',
            contentType: ReaderContentType.transcript,
            fullText: sampleTranscript,
          ),
        ),
      );

      expect(find.text('Theology 101 Lecture'), findsOneWidget);
      expect(find.text('FULL TRANSCRIPT'), findsOneWidget);
      expect(find.text('200 words'), findsOneWidget);
      expect(find.text('~1 min read'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('Renders AI Summary Reader with correct styling and content', (tester) async {
      const sampleSummary = 'This is an executive summary of the semester coursework. '
          'It covers covenant theology, historical context, and practical ministry implications.';

      await tester.pumpWidget(
        MaterialApp(
          home: FullContentReaderScreen(
            noteTitle: 'Course Overview',
            contentType: ReaderContentType.aiSummary,
            fullText: sampleSummary,
          ),
        ),
      );

      expect(find.text('Course Overview'), findsOneWidget);
      expect(find.text('EXECUTIVE SUMMARY'), findsOneWidget);
      expect(find.textContaining('This is an executive summary'), findsOneWidget);
    });

    testWidgets('Handles empty content gracefully without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FullContentReaderScreen(
            noteTitle: 'Empty Note',
            contentType: ReaderContentType.textNote,
            fullText: '',
          ),
        ),
      );

      expect(find.text('No content to display.'), findsOneWidget);
      expect(find.text('0 words'), findsOneWidget);
    });
  });
}
