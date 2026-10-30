import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Google Gemini AI Service powered by Firebase AI Logic (Gemini Developer API)
/// Operates on the Firebase Spark (free) plan and protected via Firebase App Check.
class GeminiService {
  static const List<String> _models = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
  ];

  /// App Check and Firebase AI Logic handle authentication automatically without raw client keys.
  bool get isConfigured => true;

  static DateTime? _lastAppCheckFailure;
  static const Duration _appCheckCooldown = Duration(seconds: 15);

  bool _isAppCheckError(dynamic error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('firebase_app_check') ||
        msg.contains('appcheck') ||
        msg.contains('app-check') ||
        msg.contains('too many attempts');
  }

  String _cleanError(dynamic error) {
    final msg = error.toString();
    final lower = msg.toLowerCase();

    // 1. App Check / Device Verification Errors (Checked FIRST to avoid misclassifying as generic quota/rate limit)
    if (_isAppCheckError(error)) {
      if (lower.contains('too many attempts')) {
        return 'Device verification throttled (App Check: Too many attempts). Please wait a moment for the temporary cooldown to expire.';
      }
      return 'Device verification failed (Firebase App Check). Please ensure your device is registered in the Firebase Console.';
    }

    // 2. Gemini Spark Plan Quota / Rate Limit
    if (lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('429')) {
      return 'Gemini Spark plan quota reached. Please wait a few seconds and try again.';
    }

    // 3. Transient Service Availability
    if (lower.contains('high demand') ||
        lower.contains('unavailable') ||
        lower.contains('503')) {
      return 'AI service is temporarily busy. Please tap again in a moment.';
    }

    // 4. Network / Connectivity
    if (lower.contains('timeout') || lower.contains('socketexception')) {
      return 'Connection timeout. Please check your internet connection.';
    }

    return 'AI request failed: $msg';
  }

  /// Core method — sends prompt via Firebase AI Logic on the Spark plan
  Future<String> _prompt(String prompt) async {
    // Prevent hammering the App Check token-exchange endpoint during active lockout
    if (_lastAppCheckFailure != null) {
      final elapsed = DateTime.now().difference(_lastAppCheckFailure!);
      if (elapsed < _appCheckCooldown) {
        final remainingSec = (_appCheckCooldown - elapsed).inSeconds;
        throw Exception(
          'App Check verification cooldown active. Please wait ${remainingSec > 0 ? remainingSec : 1}s before retrying.',
        );
      }
    }

    final ai = FirebaseAI.googleAI();
    String lastCleanError =
        'AI service temporarily unavailable. Please try again.';

    for (final modelName in _models) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final model = ai.generativeModel(
            model: modelName,
            generationConfig: GenerationConfig(
              temperature: 0.4,
              maxOutputTokens: 1024,
            ),
          );

          final response = await model
              .generateContent([Content.text(prompt)])
              .timeout(const Duration(seconds: 40));

          final text = response.text;
          if (text != null && text.trim().isNotEmpty) {
            _lastAppCheckFailure = null; // Clear failure record on success
            return text.trim();
          }
        } catch (e) {
          debugPrint(
            'Firebase AI Logic error on $modelName (attempt $attempt): $e',
          );
          lastCleanError = _cleanError(e);

          // If the failure is an App Check token-exchange or verification error,
          // FAIL FAST IMMEDIATELY. Do NOT retry or fall back to other models,
          // because App Check is client-level, not model-specific.
          if (_isAppCheckError(e)) {
            _lastAppCheckFailure = DateTime.now();
            throw Exception(lastCleanError);
          }

          if (attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
      }
    }

    throw Exception(lastCleanError);
  }

  // ── AUTO-TITLE ────────────────────────────────────────────────────────────

  /// Generate a smart, professional topic title (3-6 words) like ChatGPT / Gemini.
  Future<String> generateTitle(String text) async {
    final prompt =
        'You are an intelligent note organizer like ChatGPT or Gemini. '
        'Generate a smart, concise, professional topic title (3 to 6 words maximum) that captures the core subject of the following note. '
        'Do NOT copy sentences verbatim. Do NOT use quotation marks, asterisks, or markdown. Return ONLY the plain title.\n\n'
        'Content:\n$text';
    try {
      final rawTitle = await _prompt(prompt);
      final cleaned =
          rawTitle
              .replaceAll(RegExp(r'''[*"'`#]'''), '')
              .replaceFirst(
                RegExp(r'^(Title|Topic):\s*', caseSensitive: false),
                '',
              )
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      return cleaned.isEmpty ? 'Untitled Note' : cleaned;
    } catch (_) {
      // Fallback: use first 5 words of text
      final words = text.trim().split(RegExp(r'\s+')).take(5).join(' ');
      return words.isEmpty ? 'Voice Note' : words;
    }
  }

  // ── SUMMARIZATION ─────────────────────────────────────────────────────────

  Future<String> summarizeText(String text) async {
    final prompt =
        'Summarize the following note in 2-3 concise sentences. '
        'Be informative and clear. Return only the summary.\n\n$text';
    return await _prompt(prompt);
  }

  // ── KEYWORDS ─────────────────────────────────────────────────────────────

  Future<List<String>> extractKeywords(String text) async {
    final prompt =
        'Extract 5-10 important keywords or key phrases from this text. '
        'Return them as a comma-separated list only, no numbering, no extra text.\n\n$text';
    final result = await _prompt(prompt);
    return result
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
  }

  // ── ACTION ITEMS ─────────────────────────────────────────────────────────

  Future<List<String>> extractActionItems(String text) async {
    final prompt =
        'Extract specific action items or tasks from this note. '
        'Return them as a newline-separated list with each item starting with a dash (-). '
        'If there are none, return "- No action items found".\n\n$text';
    final result = await _prompt(prompt);
    return result
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^-\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  // ── SENTIMENT ─────────────────────────────────────────────────────────────

  Future<String> analyzeSentiment(String text) async {
    final prompt =
        'Analyze the sentiment of this text. '
        'Return exactly one word: "positive", "negative", or "neutral".\n\n$text';
    final result = await _prompt(prompt);
    final lower = result.toLowerCase().trim();
    if (lower.contains('positive')) return 'positive';
    if (lower.contains('negative')) return 'negative';
    return 'neutral';
  }

  // ── TRANSLATION ──────────────────────────────────────────────────────────

  Future<String> translateText(String text, String targetLanguage) async {
    final prompt =
        'Translate the following text to $targetLanguage. '
        'Return only the translated text, nothing else.\n\n$text';
    return await _prompt(prompt);
  }

  Map<String, String> getAvailableTranslations() {
    return {
      'French': 'French',
      'Spanish': 'Spanish',
      'German': 'German',
      'Yoruba': 'Yoruba',
      'Igbo': 'Igbo',
      'Hausa': 'Hausa',
      'Arabic': 'Arabic',
      'Portuguese': 'Portuguese',
    };
  }

  // ── Q&A ──────────────────────────────────────────────────────────────────

  Future<String> answerQuestion(String context, String question) async {
    final prompt =
        'Based ONLY on the following note content, answer this question: "$question"\n\n'
        'Note content:\n$context\n\n'
        'If the answer is not in the note, say "This information is not in the note."';
    return await _prompt(prompt);
  }
}
