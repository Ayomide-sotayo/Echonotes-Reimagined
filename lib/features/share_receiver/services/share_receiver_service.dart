import 'dart:async';
import 'dart:io';
import 'package:echonotes/core/app_routes.dart';
import 'package:echonotes/features/share_receiver/models/shared_audio_payload.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service managing incoming shared audio from external apps (WhatsApp, Files, etc.)
class ShareReceiverService {
  static final ShareReceiverService _instance =
      ShareReceiverService._internal();
  factory ShareReceiverService() => _instance;
  ShareReceiverService._internal();

  static const String _channelName = 'com.example.echonotes/share_receiver';
  static const MethodChannel _channel = MethodChannel(_channelName);
  static const String _prefKeyPendingAudio = 'pending_shared_audio_json';

  final ValueNotifier<SharedAudioPayload?> pendingAudioNotifier =
      ValueNotifier<SharedAudioPayload?>(null);

  final Map<String, DateTime> _recentImportTimestamps = <String, DateTime>{};
  bool _isInitialized = false;
  bool isImportScreenActive = false;

  bool get hasPendingImport => pendingAudioNotifier.value != null;
  SharedAudioPayload? get currentPending => pendingAudioNotifier.value;

  /// Initialize channel listeners, check cold-start audio, and restore any pending unauthenticated import.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Register MethodChannel call handler for warm-start and background events
    _channel.setMethodCallHandler(_handleNativeCall);

    // 2. Restore any persisted pending import from previous unauthenticated session
    await _loadPersistedPendingAudio();

    // 3. Check for cold-start share intent from native Android
    try {
      final initialData = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getInitialSharedAudio');
      if (initialData != null) {
        final payload = SharedAudioPayload.fromMap(
          Map<String, dynamic>.from(initialData),
        );
        handleIncomingAudio(payload);
      }
    } catch (e) {
      debugPrint('[ShareReceiverService] Error checking initial audio: $e');
    }

    // 4. Purge stale cached audio older than 24 hours
    unawaited(_purgeStaleTempFiles());
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSharedAudioReceived':
        if (call.arguments is Map) {
          final payload = SharedAudioPayload.fromMap(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          handleIncomingAudio(payload);
        }
        return true;
      default:
        return null;
    }
  }

  /// Process incoming audio payload safely with validation and deduplication
  void handleIncomingAudio(SharedAudioPayload payload) {
    // 1. Debounce duplicate triggers within a 3-second window
    final now = DateTime.now();
    final lastSeen = _recentImportTimestamps[payload.id];
    if (lastSeen != null && now.difference(lastSeen).inSeconds < 3) {
      debugPrint('[ShareReceiverService] Duplicate audio ignored (within 3s): ${payload.id}');
      return;
    }
    _recentImportTimestamps[payload.id] = now;

    // Keep memory cache trimmed
    if (_recentImportTimestamps.length > 50) {
      _recentImportTimestamps.remove(_recentImportTimestamps.keys.first);
    }

    // 2. Validate file readability and format
    if (!payload.isValid) {
      debugPrint(
        '[ShareReceiverService] Invalid shared audio: ${payload.name} (exists=${payload.exists}, size=${payload.size})',
      );
      _showErrorSnackBar(
        'The shared file "${payload.name}" is either empty or not a supported audio format.',
      );
      _deleteLocalFile(payload.path);
      return;
    }

    // 3. Store in pending state
    pendingAudioNotifier.value = payload;

    // 4. Check authentication status
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _triggerImportScreen(payload);
    } else {
      // User is not authenticated: persist to SharedPreferences so they don't lose the file
      _persistPendingAudio(payload);
      _showNoticeSnackBar(
        '🎙️ Audio recording "${payload.name}" received! Please sign in to import.',
      );
    }
  }

  /// Programmatically open the Share Import Screen with retry mechanism
  void _triggerImportScreen(SharedAudioPayload payload) {
    if (isImportScreenActive) return;
    void tryPush(int attempts) {
      if (isImportScreenActive) return;
      final nav = AppRoutes.navigatorKey.currentState;
      if (nav != null && nav.mounted) {
        nav.pushNamed(
          AppRoutes.shareImport,
          arguments: payload,
        );
      } else if (attempts < 8) {
        Future.delayed(
          const Duration(milliseconds: 250),
          () => tryPush(attempts + 1),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryPush(0));
  }

  /// Discard pending audio and safely delete temp file from disk
  Future<void> clearPendingAudio({bool deleteFile = true}) async {
    final payload = pendingAudioNotifier.value;
    if (payload != null) {
      _recentImportTimestamps.remove(payload.id);
      if (deleteFile) {
        _deleteLocalFile(payload.path);
      }
    }
    pendingAudioNotifier.value = null;
    await _clearPersistedPendingAudio();
  }

  Future<void> _persistPendingAudio(SharedAudioPayload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyPendingAudio, payload.toJson());
    } catch (e) {
      debugPrint('[ShareReceiverService] Failed to persist pending audio: $e');
    }
  }

  Future<void> _loadPersistedPendingAudio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKeyPendingAudio);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final payload = SharedAudioPayload.fromJson(jsonStr);
        if (payload.isValid) {
          pendingAudioNotifier.value = payload;
        } else {
          await _clearPersistedPendingAudio();
        }
      }
    } catch (e) {
      debugPrint('[ShareReceiverService] Failed to restore pending audio: $e');
    }
  }

  Future<void> _clearPersistedPendingAudio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyPendingAudio);
    } catch (_) {}
  }

  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  /// Clean up orphaned files in cache older than 24 hours
  Future<void> _purgeStaleTempFiles() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final sharedDir = Directory('${cacheDir.path}/shared_audio');
      if (!sharedDir.existsSync()) return;

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      final files = sharedDir.listSync();
      for (final entity in files) {
        if (entity is File) {
          final stat = entity.statSync();
          if (stat.modified.isBefore(cutoff)) {
            // If it's not the currently pending file, delete it
            if (pendingAudioNotifier.value?.path != entity.path) {
              entity.deleteSync();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ShareReceiverService] Stale file purge error: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    final context = AppRoutes.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNoticeSnackBar(String message) {
    final context = AppRoutes.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Open the share import screen for any currently pending audio
  void openPendingImportIfAvailable() {
    final payload = pendingAudioNotifier.value;
    if (payload != null && payload.isValid) {
      _triggerImportScreen(payload);
    }
  }

  void dispose() {
    pendingAudioNotifier.dispose();
  }
}
