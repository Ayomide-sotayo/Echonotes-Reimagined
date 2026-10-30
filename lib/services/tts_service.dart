import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.stopped;

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;

  Function(TtsState)? onStateChanged;

  Future<void> _initTts() async {
    try {
      _flutterTts.setStartHandler(() {
        _state = TtsState.playing;
        onStateChanged?.call(_state);
      });

      _flutterTts.setCompletionHandler(() {
        _state = TtsState.stopped;
        onStateChanged?.call(_state);
      });

      _flutterTts.setCancelHandler(() {
        _state = TtsState.stopped;
        onStateChanged?.call(_state);
      });

      _flutterTts.setPauseHandler(() {
        _state = TtsState.paused;
        onStateChanged?.call(_state);
      });

      _flutterTts.setErrorHandler((msg) {
        _state = TtsState.stopped;
        onStateChanged?.call(_state);
      });

      await _flutterTts.setLanguage('en-US');
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    final cleanText =
        text
            .replaceAll(RegExp(r'''[*"'`#_]'''), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (cleanText.isEmpty) return;

    try {
      if (_state == TtsState.playing) {
        await stop();
      }
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      _state = TtsState.playing;
      onStateChanged?.call(_state);
      await _flutterTts.speak(cleanText);
    } catch (e) {
      _state = TtsState.stopped;
      onStateChanged?.call(_state);
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _state = TtsState.stopped;
    onStateChanged?.call(_state);
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (_) {}
    _state = TtsState.paused;
    onStateChanged?.call(_state);
  }
}
