import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AssemblyAIService {
  static const List<String> _keyCandidates = [
    'ASSEMBLY_AI_KEY',
    'ASSEMBLYAI_API_KEY',
    'ASSEMBLY_AI_API_KEY',
    'ASSEMBLYAI_KEY',
    'ASSEMBLY_KEY',
  ];

  /// Retrieve the active AssemblyAI key across common environment conventions:
  /// flutter_dotenv (.env), --dart-define (compile-time), and Platform.environment.
  String get apiKey {
    // 1. Check flutter_dotenv
    for (final key in _keyCandidates) {
      final val = dotenv.maybeGet(key);
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    // 2. Check --dart-define
    for (final key in _keyCandidates) {
      final val = String.fromEnvironment(key);
      if (val.trim().isNotEmpty) return val.trim();
    }
    // 3. Check Platform.environment
    try {
      for (final key in _keyCandidates) {
        final val = Platform.environment[key];
        if (val != null && val.trim().isNotEmpty) return val.trim();
      }
    } catch (_) {}
    return '';
  }

  final String baseUrl = 'https://api.assemblyai.com/v2';

  void _logDiagnostic(String message) {
    debugPrint('[AssemblyAI Diagnostic] $message');
  }

  String _redactUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final filename =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'audio';
      return '${uri.scheme}://${uri.host}/.../$filename';
    } catch (_) {
      return '[redacted-audio-url]';
    }
  }

  String _redactId(String id) {
    if (id.length <= 6) return '***';
    return '${id.substring(0, 4)}***${id.substring(id.length - 2)}';
  }

  String _extractProviderError(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is Map) {
        if (parsed.containsKey('error')) return parsed['error'].toString();
        if (parsed.containsKey('message')) return parsed['message'].toString();
      }
    } catch (_) {}
    return responseBody.length > 120
        ? '${responseBody.substring(0, 120)}...'
        : responseBody;
  }

  /// Upload local audio bytes directly to AssemblyAI CDN.
  /// Returns the internal upload_url, or null on failure.
  Future<String?> uploadAudioBytes(List<int> bytes) async {
    final key = apiKey;
    if (key.isEmpty) {
      _logDiagnostic(
        'Upload aborted: No AssemblyAI API key found in candidate variables (${_keyCandidates.join(", ")})',
      );
      return null;
    }

    try {
      _logDiagnostic(
        'Uploading ${bytes.length} bytes directly to AssemblyAI CDN...',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/upload'),
        headers: {
          'Authorization': key,
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );

      _logDiagnostic('CDN upload response HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        final uploadUrl = jsonDecode(response.body)['upload_url'] as String?;
        if (uploadUrl != null) {
          _logDiagnostic(
            'CDN upload succeeded: ${_redactUrl(uploadUrl)}',
          );
          return uploadUrl;
        }
      } else {
        final errorMsg = _extractProviderError(response.body);
        _logDiagnostic(
          'CDN upload rejected: HTTP ${response.statusCode} - $errorMsg',
        );
      }
    } catch (e) {
      _logDiagnostic('CDN upload network exception: $e');
    }
    return null;
  }

  /// Transcribe audio from a public URL or local audio bytes.
  /// Returns the transcript text, or null on failure.
  Future<String?> transcribeAudio(
    String audioUrl, {
    List<int>? audioBytes,
  }) async {
    final key = apiKey;
    if (key.isEmpty) {
      _logDiagnostic(
        'Transcription aborted: API key missing from environment (checked: ${_keyCandidates.join(", ")})',
      );
      return null;
    }

    try {
      String targetUrl = audioUrl;

      // Ensure audio bytes are available: if not supplied directly, fetch from audioUrl
      List<int>? effectiveBytes = audioBytes;
      if ((effectiveBytes == null || effectiveBytes.isEmpty) &&
          audioUrl.startsWith('http')) {
        try {
          _logDiagnostic('Fetching audio from URL for direct CDN push: ${_redactUrl(audioUrl)}');
          final fetchResponse = await http.get(Uri.parse(audioUrl));
          if (fetchResponse.statusCode == 200 &&
              fetchResponse.bodyBytes.isNotEmpty) {
            effectiveBytes = fetchResponse.bodyBytes;
            _logDiagnostic(
              'Fetched ${effectiveBytes.length} bytes for direct CDN upload',
            );
          }
        } catch (e) {
          _logDiagnostic('Audio URL fetch notice: $e');
        }
      }

      // If audioBytes available, push directly to AssemblyAI CDN for maximum reliability
      if (effectiveBytes != null && effectiveBytes.isNotEmpty) {
        final cdnUrl = await uploadAudioBytes(effectiveBytes);
        if (cdnUrl != null && cdnUrl.isNotEmpty) {
          targetUrl = cdnUrl;
        } else {
          _logDiagnostic(
            'CDN byte upload fallback to audio URL: ${_redactUrl(audioUrl)}',
          );
        }
      } else {
        _logDiagnostic(
          'Submitting transcription with remote audio URL: ${_redactUrl(audioUrl)}',
        );
      }

      // 1. Submit transcription job
      final submitResponse = await http.post(
        Uri.parse('$baseUrl/transcript'),
        headers: {
          'Authorization': key,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'audio_url': targetUrl}),
      );

      _logDiagnostic('Submit response HTTP ${submitResponse.statusCode}');

      if (submitResponse.statusCode != 200) {
        final errorMsg = _extractProviderError(submitResponse.body);
        _logDiagnostic(
          'Submit rejected: HTTP ${submitResponse.statusCode} - $errorMsg',
        );
        return null;
      }

      final transcriptId = jsonDecode(submitResponse.body)['id'] as String?;
      if (transcriptId == null) {
        _logDiagnostic('Submit error: No transcript ID in provider payload');
        return null;
      }

      _logDiagnostic(
        'Transcription job queued. Assigned ID: ${_redactId(transcriptId)}',
      );

      // 2. Poll with a maximum of 60 attempts (2 min timeout)
      const maxAttempts = 60;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        await Future.delayed(const Duration(seconds: 2));

        final statusResponse = await http.get(
          Uri.parse('$baseUrl/transcript/$transcriptId'),
          headers: {'Authorization': key},
        );

        if (statusResponse.statusCode != 200) {
          final errorMsg = _extractProviderError(statusResponse.body);
          _logDiagnostic(
            'Poll attempt $attempt/$maxAttempts HTTP ${statusResponse.statusCode} - $errorMsg',
          );
          continue;
        }

        final result = jsonDecode(statusResponse.body);
        final status = result['status'] as String?;

        _logDiagnostic(
          'Job ${_redactId(transcriptId)} status: $status (attempt $attempt/$maxAttempts)',
        );

        switch (status) {
          case 'completed':
            final text = result['text'] as String?;
            _logDiagnostic('Job ${_redactId(transcriptId)} completed successfully.');
            if (text == null || text.trim().isEmpty) {
              return '[No speech detected]';
            }
            return text;
          case 'error':
          case 'failed':
            final providerError = result['error'] ?? 'Transcription failed';
            _logDiagnostic(
              'Job ${_redactId(transcriptId)} failed: $providerError',
            );
            return null;
          default:
            // 'queued' or 'processing' — keep polling
            break;
        }
      }

      _logDiagnostic(
        'Job ${_redactId(transcriptId)} timed out after $maxAttempts attempts (120s)',
      );
      return null;
    } catch (e) {
      _logDiagnostic('Transcription pipeline exception: $e');
      return null;
    }
  }
}
