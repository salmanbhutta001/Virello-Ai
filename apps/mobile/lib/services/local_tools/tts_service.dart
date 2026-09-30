/// Local text-to-speech voiceover service — wraps flutter_tts.
///
/// Uses the device's own TTS engine, so voiceover works offline with no
/// account, no key, and no extra setup. Prefers an Urdu (ur-PK) voice when
/// available, otherwise falls back to English. All platform calls are
/// guarded: failures degrade to no-ops / nulls, never crashes.
library;

import 'package:flutter_tts/flutter_tts.dart';

class TtsVoice {
  final String name;
  final String locale;
  const TtsVoice({required this.name, required this.locale});
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _disposed = false;

  /// One-time setup. Safe to call repeatedly.
  Future<void> init() async {
    if (_ready || _disposed) return;
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (_) {
      // TTS unavailable on this device — calls stay guarded.
    }
  }

  Future<void> speak(String text, {String? language}) async {
    if (_disposed || text.trim().isEmpty) return;
    await init();
    try {
      if (language != null && language.isNotEmpty) {
        await _tts.setLanguage(language);
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate.clamp(0.1, 1.0));
    } catch (_) {}
  }

  Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
    } catch (_) {}
  }

  Future<List<String>> languages() async {
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        return langs.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<List<TtsVoice>> voices() async {
    try {
      final vs = await _tts.getVoices;
      if (vs is List) {
        return vs
            .whereType<Map>()
            .map((m) => TtsVoice(
                  name: (m['name'] ?? '').toString(),
                  locale: (m['locale'] ?? '').toString(),
                ))
            .where((v) => v.name.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Picks the best voice: ur-PK/ur first, then en-*, then anything.
  Future<TtsVoice?> pickVoice({List<TtsVoice>? from}) async {
    final vs = from ?? await voices();
    if (vs.isEmpty) return null;
    for (final v in vs) {
      final loc = v.locale.toLowerCase();
      if (loc.startsWith('ur')) return v;
    }
    for (final v in vs) {
      final loc = v.locale.toLowerCase();
      if (loc.startsWith('en')) return v;
    }
    return vs.first;
  }

  Future<void> useVoice(TtsVoice voice) async {
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    } catch (_) {}
  }

  /// Renders [text] to an audio file. [fileName] may be a plain name
  /// ("voiceover.wav") or, with [isFullPath]=true, an absolute path.
  /// Returns the platform result (path or status code), or null on failure.
  /// Where the file lands is platform-defined — the UI reports it honestly.
  Future<dynamic> synthesizeToFile(
    String text,
    String fileName, {
    bool isFullPath = false,
  }) async {
    if (_disposed || text.trim().isEmpty) return null;
    await init();
    try {
      return await _tts.synthesizeToFile(text, fileName, isFullPath);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    try {
      _tts.stop();
    } catch (_) {}
  }
}
