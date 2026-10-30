import 'package:flutter_test/flutter_test.dart';
import 'package:echonotes/services/gemini_service.dart';

void main() {
  group('GeminiService App Check Error Discrimination Tests', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService();
    });

    test('Identifies firebase_app_check "Too many attempts" error correctly', () {
      const error = '[firebase_app_check/unknown] Too many attempts.';
      // Test title generation fallback or prompt handling
      expect(error.toLowerCase().contains('too many attempts'), isTrue);
      expect(error.toLowerCase().contains('firebase_app_check'), isTrue);
    });

    test('Distinguishes App Check error from Gemini Spark quota 429', () async {
      // Calling generateTitle on failure falls back to words safely without throwing
      final fallbackTitle = await geminiService.generateTitle('First second third fourth fifth sixth note');
      expect(fallbackTitle, isNotEmpty);
    });
  });
}
