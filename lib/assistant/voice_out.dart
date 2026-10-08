import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'lang_util.dart';

/// Reads assistant replies aloud with the phone's built-in voices
/// (free and offline). Pashto has no Android voice, so it stays silent.
class VoiceOut {
  VoiceOut._();

  static final _tts = FlutterTts();
  static final Map<String, bool> _available = {};
  static String? _currentLocale;

  /// Starts the speech engine and picks the voice ahead of time, so the
  /// first reply starts speaking straight away.
  static Future<void> warmUp(ChatLang lang) async {
    try {
      if (!await canSpeak(lang)) return;
      await _use(_locale(lang));
    } catch (_) {}
  }


  static Future<void> _use(String loc) async {
    if (_currentLocale == loc) return;
    await _tts.awaitSpeakCompletion(false);
    await _tts.setLanguage(loc);
    await _tts.setSpeechRate(0.55);
    _currentLocale = loc;
  }
  static bool get supported => !kIsWeb;

  static String _locale(ChatLang lang) => switch (lang) {
        ChatLang.en => 'en-US',
        ChatLang.romanUrdu || ChatLang.romanPashto => 'en-IN', // reads typed Urdu/Pashto more naturally
        ChatLang.ur => 'ur-PK',
        ChatLang.ps => 'ps-AF',
      };

  static Future<bool> canSpeak(ChatLang lang) async {
    if (!supported) return false;
    final loc = _locale(lang);
    if (_available.containsKey(loc)) return _available[loc]!;
    var ok = false;
    try {
      ok = (await _tts.isLanguageAvailable(loc)) == true;
    } catch (_) {}
    return _available[loc] = ok;
  }

  static Future<void> speak(String text, ChatLang lang) async {
    if (!await canSpeak(lang)) return;
    final clean = text
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]️?', unicode: true), '')
        .replaceAll('•', '')
        .trim();
    if (clean.isEmpty) return;
    try {
      await _tts.stop();
      await _use(_locale(lang));
      await _tts.speak(clean);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
