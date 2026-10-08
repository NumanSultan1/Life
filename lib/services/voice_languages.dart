import 'package:hive_flutter/hive_flutter.dart';
import 'hive_service.dart';

/// A language for voice typing (and the source for translation).
class VoiceLanguage {
  final String code; // speech locale, e.g. ur_PK
  final String name, native;
  final bool rtl;

  const VoiceLanguage(this.code, this.name, this.native, {this.rtl = false});

  /// Two-letter language code (for matching and translation).
  String get lang => code.split('_').first;
}

const voiceLanguages = [
  VoiceLanguage('en_US', 'English', 'English'),
  VoiceLanguage('ur_PK', 'Urdu', 'اردو', rtl: true),
  VoiceLanguage('ps_AF', 'Pashto', 'پښتو', rtl: true),
  VoiceLanguage('hi_IN', 'Hindi', 'हिन्दी'),
  VoiceLanguage('pa_IN', 'Punjabi', 'ਪੰਜਾਬੀ'),
  VoiceLanguage('ar_SA', 'Arabic', 'العربية', rtl: true),
  VoiceLanguage('fa_IR', 'Persian', 'فارسی', rtl: true),
  VoiceLanguage('bn_BD', 'Bengali', 'বাংলা'),
  VoiceLanguage('tr_TR', 'Turkish', 'Türkçe'),
  VoiceLanguage('es_ES', 'Spanish', 'Español'),
  VoiceLanguage('fr_FR', 'French', 'Français'),
  VoiceLanguage('de_DE', 'German', 'Deutsch'),
  VoiceLanguage('zh_CN', 'Chinese', '中文'),
];

class VoiceLanguageSetting {
  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _key => '${HiveService.getCurrentUser()}_voiceLang';

  static VoiceLanguage get current {
    final code = _box.get(_key, defaultValue: 'en_US') as String;
    return voiceLanguages.firstWhere((l) => l.code == code, orElse: () => voiceLanguages.first);
  }

  static Future<void> set(VoiceLanguage l) => _box.put(_key, l.code);

  static bool get translateConsent => _box.get('${HiveService.getCurrentUser()}_translateConsent', defaultValue: false) as bool;
  static Future<void> giveTranslateConsent() => _box.put('${HiveService.getCurrentUser()}_translateConsent', true);
}

/// True when the text is mostly right-to-left script (Urdu, Pashto, Arabic…).
bool isRtlText(String text) {
  for (final r in text.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFEFC)) return true;
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) return false;
  }
  return false;
}
