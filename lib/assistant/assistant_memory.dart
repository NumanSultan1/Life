import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import 'lang_util.dart';

/// What a taught phrase means: an action type plus fixed parameters.
class LearnedMeaning {
  final String type; // task, reminder, journal, water, mood, habit, medicine, chat
  final Map<String, dynamic> params;

  const LearnedMeaning(this.type, [this.params = const {}]);

  Map<String, dynamic> toMap() => {'type': type, 'params': params};
  static LearnedMeaning fromMap(Map m) => LearnedMeaning(m['type'] as String, Map<String, dynamic>.from((m['params'] as Map?) ?? const {}));
}

/// A fact the user told the assistant ("Abu is my father").
class MemoryFact {
  final String text;
  final DateTime added;

  const MemoryFact(this.text, this.added);
}

/// How the user likes to be talked to.
class AssistantStyle {
  final String? name; // what to call the user
  final bool short;
  final bool emoji;
  final bool casual;
  final bool speak; // read replies aloud

  const AssistantStyle({this.name, this.short = false, this.emoji = true, this.casual = true, this.speak = true});

  AssistantStyle copyWith({String? name, bool? short, bool? emoji, bool? casual, bool? speak}) => AssistantStyle(
        name: name ?? this.name,
        short: short ?? this.short,
        emoji: emoji ?? this.emoji,
        casual: casual ?? this.casual,
        speak: speak ?? this.speak,
      );

  Map<String, dynamic> toMap() => {'name': name, 'short': short, 'emoji': emoji, 'casual': casual, 'speak': speak};
  static AssistantStyle fromMap(Map m) => AssistantStyle(
        name: m['name'] as String?,
        short: (m['short'] ?? false) as bool,
        emoji: (m['emoji'] ?? true) as bool,
        casual: (m['casual'] ?? true) as bool,
        speak: (m['speak'] ?? true) as bool,
      );
}

/// Everything the assistant has learned about this user, stored on the
/// phone (and included in backups).
class AssistantMemory {
  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _key => '${HiveService.getCurrentUser()}_assistantMemory';
  static const _maxPhrases = 300, _maxFacts = 200;

  static Map<String, dynamic> get _data => Map<String, dynamic>.from((_box.get(_key) as Map?) ?? const {});
  static Future<void> _save(Map<String, dynamic> d) => _box.put(_key, d);

  static String _norm(String s) => tokens(normalizeDigits(s)).join(' ');

  // --- Taught phrases ---

  static Map<String, LearnedMeaning> get phrases {
    final raw = (_data['phrases'] as Map?) ?? const {};
    return {for (final e in raw.entries) e.key as String: LearnedMeaning.fromMap(e.value as Map)};
  }

  static Future<void> teach(String phrase, LearnedMeaning meaning) async {
    final d = _data;
    final p = Map<String, dynamic>.from((d['phrases'] as Map?) ?? const {});
    p.remove(_norm(phrase));
    p[_norm(phrase)] = meaning.toMap();
    while (p.length > _maxPhrases) {
      p.remove(p.keys.first);
    }
    d['phrases'] = p;
    await _save(d);
  }

  /// Forgets a tapped meaning for [text] (when the user teaches it again).
  static Future<void> forgetPhraseText(String text) => forgetPhrase(_norm(text));

  static Future<void> forgetPhrase(String phrase) async {
    final d = _data;
    final p = Map<String, dynamic>.from((d['phrases'] as Map?) ?? const {})..remove(phrase);
    d['phrases'] = p;
    await _save(d);
  }

  /// The taught meaning that best matches [text] (exact, contained, or
  /// mostly the same words), or null.
  static (String, LearnedMeaning)? match(String text) {
    final t = _norm(text);
    if (t.isEmpty) return null;
    final words = t.split(' ').toSet();
    (String, LearnedMeaning)? best;
    var bestScore = 0.0;
    for (final e in phrases.entries) {
      if (e.key == t) return (e.key, e.value);
      final pw = e.key.split(' ').toSet();
      double score;
      if (pw.length >= 2 && ' $t '.contains(' ${e.key} ')) {
        score = 0.9;
      } else {
        final inter = words.intersection(pw).length;
        score = inter / (words.union(pw).length);
      }
      if (score > bestScore) {
        bestScore = score;
        best = (e.key, e.value);
      }
    }
    return bestScore >= 0.75 ? best : null;
  }

  // --- Meanings ("za kha yam = I am fine") ---

  /// Phrases in the user's language with the English meaning they taught.
  static Map<String, String> get meanings => Map<String, String>.from((_data['meanings'] as Map?) ?? const {});

  static Future<void> addMeaning(String phrase, String meaning, {ChatLang? lang}) async {
    final d = _data;
    final m = Map<String, dynamic>.from((d['meanings'] as Map?) ?? const {});
    final l = Map<String, dynamic>.from((d['meaningLangs'] as Map?) ?? const {});
    m[phrase.trim()] = meaning.trim();
    if (lang != null) l[phrase.trim()] = lang.name;
    while (m.length > _maxPhrases) {
      l.remove(m.keys.first);
      m.remove(m.keys.first);
    }
    d['meanings'] = m;
    d['meaningLangs'] = l;
    await _save(d);
  }

  /// The style (e.g. Roman Pashto) the user taught a phrase in that
  /// appears in [text], so the reply can match it.
  static ChatLang? meaningLangIn(String text) {
    final langs = (_data['meaningLangs'] as Map?) ?? const {};
    final lower = text.toLowerCase();
    for (final e in meanings.keys.toList()..sort((a, b) => b.length.compareTo(a.length))) {
      if (lower.contains(e.toLowerCase())) {
        final name = langs[e] as String?;
        return ChatLang.values.where((l) => l.name == name).firstOrNull;
      }
    }
    return null;
  }

  static Future<void> removeMeaning(String phrase) async {
    final d = _data;
    d['meanings'] = Map<String, dynamic>.from((d['meanings'] as Map?) ?? const {})..remove(phrase);
    await _save(d);
  }

  /// Replaces taught phrases with their English meaning (longest first), so
  /// "saba sahar 8 baje dawai yaad ra kra" can be understood.
  static String applyMeanings(String text) {
    var out = text;
    final list = meanings.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in list) {
      final latin = RegExp(r'[a-zA-Z]').hasMatch(e.key);
      final pattern = latin ? RegExp('(?<![a-zA-Z])${RegExp.escape(e.key)}(?![a-zA-Z])', caseSensitive: false) : RegExp(RegExp.escape(e.key));
      out = out.replaceAll(pattern, e.value);
    }
    return out;
  }

  // --- Replies the user taught ("sanga chal de" → "Za hm kha yama, ta sanga ye?") ---

  static Map<String, String> get replies => Map<String, String>.from((_data['replies'] as Map?) ?? const {});

  static Future<void> addReply(String phrase, String reply) async {
    final d = _data;
    final r = Map<String, dynamic>.from((d['replies'] as Map?) ?? const {});
    r[phrase.trim()] = reply.trim();
    while (r.length > _maxPhrases) {
      r.remove(r.keys.first);
    }
    d['replies'] = r;
    await _save(d);
  }

  static Future<void> removeReply(String phrase) async {
    final d = _data;
    d['replies'] = Map<String, dynamic>.from((d['replies'] as Map?) ?? const {})..remove(phrase);
    await _save(d);
  }

  /// The taught reply for the longest taught phrase in [text].
  static String? replyFor(String text) {
    final lower = ' ${tokens(normalizeDigits(text)).join(' ')} ';
    String? best;
    var bestLen = 0;
    for (final e in replies.entries) {
      final k = tokens(normalizeDigits(e.key)).join(' ');
      if (k.isNotEmpty && lower.contains(' $k ') && k.length > bestLen) {
        best = e.value;
        bestLen = k.length;
      }
    }
    return best;
  }

  // --- The user's own words (helps recognise their Roman Pashto/Urdu) ---

  static Future<void> learnWords(ChatLang lang, String text) async {
    if (lang != ChatLang.romanPashto && lang != ChatLang.romanUrdu) return;
    final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.length >= 2 && w.length <= 15 && !englishCommon.contains(w));
    if (words.isEmpty) return;
    final d = _data;
    final key = lang == ChatLang.romanPashto ? 'wordsPs' : 'wordsUr';
    final list = List<String>.from((d[key] as List?) ?? const []);
    for (final w in words) {
      list.remove(w);
      list.add(w);
    }
    d[key] = list.length > 400 ? list.sublist(list.length - 400) : list;
    await _save(d);
    loadLearnedWords();
  }

  /// Hands the learned words to the language detector.
  static void loadLearnedWords() {
    final d = _data;
    learnedRomanPashto = Set<String>.from((d['wordsPs'] as List?) ?? const []);
    learnedRomanUrdu = Set<String>.from((d['wordsUr'] as List?) ?? const []);
  }

  /// The style the user chats in, kept between conversations.
  static ChatLang? get chatLang {
    final name = _data['chatLang'] as String?;
    return ChatLang.values.where((l) => l.name == name).firstOrNull;
  }

  static Future<void> setChatLang(ChatLang lang) async {
    if (chatLang == lang) return;
    final d = _data;
    d['chatLang'] = lang.name;
    await _save(d);
  }

  /// How the user addresses the assistant ("yara", "yaar", "bhai"), mirrored back.
  static String? get address => _data['address'] as String?;

  static Future<void> setAddress(String? word) async {
    final d = _data;
    d['address'] = word;
    await _save(d);
  }

  // --- Word corrections (speech heard wrong) ---

  static Map<String, String> get corrections => Map<String, String>.from((_data['corrections'] as Map?) ?? const {});

  static Future<void> addCorrection(String wrong, String right) async {
    if (wrong.trim().isEmpty || wrong.trim() == right.trim()) return;
    final d = _data;
    final c = Map<String, dynamic>.from((d['corrections'] as Map?) ?? const {});
    c[wrong.trim()] = right.trim();
    d['corrections'] = c;
    await _save(d);
  }

  static Future<void> removeCorrection(String wrong) async {
    final d = _data;
    d['corrections'] = Map<String, dynamic>.from((d['corrections'] as Map?) ?? const {})..remove(wrong);
    await _save(d);
  }

  /// Learns word fixes from a sentence the user edited: the words that
  /// differ between the start and end that match ("a boo" → "Abu").
  static Future<void> learnFromEdit(String heard, String fixed) async {
    final a = heard.trim().split(RegExp(r'\s+')), b = fixed.trim().split(RegExp(r'\s+'));
    if (a.length == b.length) {
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) await addCorrection(a[i], b[i]);
      }
      return;
    }
    var start = 0;
    while (start < a.length && start < b.length && a[start] == b[start]) {
      start++;
    }
    var endA = a.length, endB = b.length;
    while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
      endA--;
      endB--;
    }
    final wrong = a.sublist(start, endA), right = b.sublist(start, endB);
    if (wrong.isNotEmpty && wrong.length <= 4 && right.length <= 4) {
      await addCorrection(wrong.join(' '), right.join(' '));
    }
  }

  /// Applies learned fixes to what speech recognition heard.
  static String applyCorrections(String text) {
    var out = text;
    final list = corrections.entries.toList()..sort((x, y) => y.key.length.compareTo(x.key.length));
    for (final e in list) {
      if (e.key.contains(' ')) {
        out = out.replaceAll(e.key, e.value);
      } else {
        out = out.split(' ').map((w) => w == e.key ? e.value : w).join(' ');
      }
    }
    return out;
  }

  // --- Facts ---

  static List<MemoryFact> get facts => ((_data['facts'] as List?) ?? const [])
      .map((m) => MemoryFact((m as Map)['text'] as String, DateTime.tryParse(m['added'] as String? ?? '') ?? DateTime.now()))
      .toList();

  static Future<void> addFact(String text) async {
    final d = _data;
    final f = List<Map>.from((d['facts'] as List?) ?? const [])
      ..removeWhere((m) => m['text'] == text)
      ..add({'text': text, 'added': DateTime.now().toIso8601String()});
    d['facts'] = f.length > _maxFacts ? f.sublist(f.length - _maxFacts) : f;
    await _save(d);
  }

  static Future<void> removeFact(String text) async {
    final d = _data;
    d['facts'] = List<Map>.from((d['facts'] as List?) ?? const [])..removeWhere((m) => m['text'] == text);
    await _save(d);
  }

  /// Facts that share words with [text], most relevant first.
  static List<String> relevantFacts(String text, {int limit = 5}) {
    final w = tokens(text).where((x) => x.length > 2).toSet();
    final scored = facts.map((f) => (f.text, tokens(f.text).toSet().intersection(w).length)).where((e) => e.$2 > 0).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  /// Names and words to help the Pashto speech model hear them.
  static String speechHints() {
    final words = <String>{
      ...corrections.values,
      for (final f in facts) ...f.text.split(' ').where((w) => w.length > 2 && RegExp(r'^[A-Z؀-ۿ]').hasMatch(w)),
    };
    return words.take(40).join(' ');
  }

  // --- Style and feedback ---

  static AssistantStyle get style => AssistantStyle.fromMap((_data['style'] as Map?) ?? const {});

  static Future<void> setStyle(AssistantStyle s) async {
    final d = _data;
    d['style'] = s.toMap();
    await _save(d);
  }

  static (int, int) get feedback {
    final f = (_data['feedback'] as Map?) ?? const {};
    return ((f['up'] ?? 0) as int, (f['down'] ?? 0) as int);
  }

  static Future<void> addFeedback(bool good) async {
    final d = _data;
    final f = Map<String, dynamic>.from((d['feedback'] as Map?) ?? const {});
    f[good ? 'up' : 'down'] = ((f[good ? 'up' : 'down'] ?? 0) as int) + 1;
    d['feedback'] = f;
    await _save(d);
  }

  static Future<void> clearAll() => _box.delete(_key);
}
