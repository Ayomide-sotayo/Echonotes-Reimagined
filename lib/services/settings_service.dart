import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service managing app-wide settings and preferences,
/// including theme mode, audio recording settings, and AI preferences.
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Keys for SharedPreferences
  static const String _keyThemeMode = 'echo_theme_mode';
  static const String _keyAudioQuality = 'echo_audio_quality';
  static const String _keyAutoTranscribe = 'echo_auto_transcribe';
  static const String _keyNoiseSuppression = 'echo_noise_suppression';
  static const String _keyLocalCache = 'echo_local_cache';
  static const String _keySummaryStyle = 'echo_summary_style';
  static const String _keyAutoInsights = 'echo_auto_insights';
  static const String _keyAvatarUrl = 'echo_avatar_url';

  // Default Avatar URL (Studio Lead Portrait)
  static const String defaultAvatarUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';

  // Curated Studio Avatars
  static const List<Map<String, String>> presetAvatars = [
    {
      'id': 'lead',
      'name': 'Studio Lead',
      'url':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'creative',
      'name': 'Creative Pro',
      'url':
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'sound',
      'name': 'Sound Engineer',
      'url':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'producer',
      'name': 'Audio Producer',
      'url':
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'designer',
      'name': 'Interface Lead',
      'url':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
    },
    {
      'id': 'architect',
      'name': 'Tech Architect',
      'url':
          'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    },
  ];

  // ValueNotifier for reactive theme switching across MaterialApp
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  // ValueNotifier for reactive avatar updates across screens
  final ValueNotifier<String> avatarUrlNotifier =
      ValueNotifier<String>(defaultAvatarUrl);

  // Audio Recording Preferences
  String _audioQuality = 'high'; // 'high' | 'standard'
  bool _autoTranscribe = true;
  bool _noiseSuppression = true;
  bool _localCache = true;

  // AI Preferences
  String _summaryStyle = 'concise'; // 'concise' | 'detailed'
  bool _autoInsights = true;

  // Getters
  String get audioQuality => _audioQuality;
  bool get autoTranscribe => _autoTranscribe;
  bool get noiseSuppression => _noiseSuppression;
  bool get localCache => _localCache;
  String get summaryStyle => _summaryStyle;
  bool get autoInsights => _autoInsights;
  String get avatarUrl => avatarUrlNotifier.value;

  /// Initialize and load saved preferences from disk
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Theme Mode
      final savedTheme = prefs.getString(_keyThemeMode);
      if (savedTheme == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else {
        themeModeNotifier.value = ThemeMode.system;
      }

      // Load Avatar URL
      final savedAvatar = prefs.getString(_keyAvatarUrl);
      if (savedAvatar != null && savedAvatar.isNotEmpty) {
        avatarUrlNotifier.value = savedAvatar;
      }

      // Load Audio Settings
      _audioQuality = prefs.getString(_keyAudioQuality) ?? 'high';
      _autoTranscribe = prefs.getBool(_keyAutoTranscribe) ?? true;
      _noiseSuppression = prefs.getBool(_keyNoiseSuppression) ?? true;
      _localCache = prefs.getBool(_keyLocalCache) ?? true;

      // Load AI Settings
      _summaryStyle = prefs.getString(_keySummaryStyle) ?? 'concise';
      _autoInsights = prefs.getBool(_keyAutoInsights) ?? true;
    } catch (e) {
      debugPrint('Error initializing SettingsService: $e');
    }
  }

  /// Change avatar URL and persist to storage
  Future<void> setAvatarUrl(String url) async {
    avatarUrlNotifier.value = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatarUrl, url);
    } catch (e) {
      debugPrint('Error saving avatar URL: $e');
    }
  }

  /// Change theme mode and persist to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'system';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      await prefs.setString(_keyThemeMode, modeStr);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Set audio recording quality ('high' or 'standard')
  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAudioQuality, quality);
    } catch (e) {
      debugPrint('Error saving audio quality: $e');
    }
  }

  /// Set auto transcription toggle
  Future<void> setAutoTranscribe(bool value) async {
    _autoTranscribe = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoTranscribe, value);
    } catch (e) {
      debugPrint('Error saving auto transcribe: $e');
    }
  }

  /// Set noise suppression toggle
  Future<void> setNoiseSuppression(bool value) async {
    _noiseSuppression = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyNoiseSuppression, value);
    } catch (e) {
      debugPrint('Error saving noise suppression: $e');
    }
  }

  /// Set local audio caching toggle
  Future<void> setLocalCache(bool value) async {
    _localCache = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLocalCache, value);
    } catch (e) {
      debugPrint('Error saving local cache: $e');
    }
  }

  /// Set AI summary style ('concise' or 'detailed')
  Future<void> setSummaryStyle(String style) async {
    _summaryStyle = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySummaryStyle, style);
    } catch (e) {
      debugPrint('Error saving summary style: $e');
    }
  }

  /// Set auto insights extraction toggle
  Future<void> setAutoInsights(bool value) async {
    _autoInsights = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoInsights, value);
    } catch (e) {
      debugPrint('Error saving auto insights: $e');
    }
  }
}
