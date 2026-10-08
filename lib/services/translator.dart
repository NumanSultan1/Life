import 'dart:convert';
import 'package:http/http.dart' as http;

/// Translates text to English with MyMemory, a free online translation
/// service. The text is sent over HTTPS only when the user taps Translate.
class Translator {
  static const _maxBytes = 450; // MyMemory's free limit is 500 bytes a request

  static Future<String> toEnglish(String text, String fromLang) async {
    final parts = _chunks(text.trim());
    final out = <String>[];
    for (final p in parts) {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {'q': p, 'langpair': '$fromLang|en'});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('Translation service error (${res.statusCode})');
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final translated = (body['responseData'] as Map?)?['translatedText'] as String?;
      if (translated == null || body['responseStatus'].toString() != '200') {
        throw Exception(body['responseDetails']?.toString() ?? 'No translation');
      }
      out.add(translated);
    }
    return out.join(' ');
  }

  /// Splits on sentence ends (including ۔ and ؟) to stay under the limit.
  static List<String> _chunks(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?۔؟\n])\s*')).where((s) => s.trim().isNotEmpty);
    final chunks = <String>[];
    var current = '';
    for (final s in sentences) {
      final next = current.isEmpty ? s : '$current $s';
      if (utf8.encode(next).length <= _maxBytes) {
        current = next;
        continue;
      }
      if (current.isNotEmpty) chunks.add(current);
      // A very long sentence: cut it by words.
      current = '';
      for (final w in s.split(' ')) {
        final n = current.isEmpty ? w : '$current $w';
        if (utf8.encode(n).length > _maxBytes && current.isNotEmpty) {
          chunks.add(current);
          current = w;
        } else {
          current = n;
        }
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }
}
