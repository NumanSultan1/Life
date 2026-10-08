import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../data/arcs.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

/// Per-user progress in the seasonal arcs, with strict rules: a day that
/// ends with any rule unchecked restarts the arc at Day 1.
class ArcProvider extends ChangeNotifier {
  static const int dayCompleteXp = 25;

  final Map<String, Map<String, dynamic>> _state = {};
  final List<String> _pendingEvents = [];

  ArcProvider() {
    loadArcs();
  }

  static String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String get _today => _fmt(DateTime.now());
  static Box get _box => Hive.box(HiveService.settingsBox);
  static String _key(String id) => '${HiveService.getCurrentUser()}_arc_$id';

  List<ArcDefinition> _custom = [];

  /// Built-in challenges followed by the user's own.
  List<ArcDefinition> get allChallenges => [...arcDefinitions, ..._custom];
  List<ArcDefinition> get customChallenges => List.unmodifiable(_custom);
  List<ArcDefinition> get joinedChallenges => allChallenges.where((a) => isJoined(a.id)).toList();

  static String get _customKey => '${HiveService.getCurrentUser()}_customChallenges';

  void loadArcs() {
    _state.clear();
    _custom = ((_box.get(_customKey) as List?) ?? const []).map((m) => ArcDefinition.fromMap(m as Map)).toList();
    for (final arc in allChallenges) {
      final raw = _box.get(_key(arc.id));
      _state[arc.id] = raw is Map ? _deepCopy(raw) : <String, dynamic>{};
      _renameOldRules(arc.id);
    }
    _enforceStrictRules();
    _enforceOneAtATime();
    notifyListeners();
  }

  /// The one challenge the user is doing (only one at a time).
  ArcDefinition? get activeChallenge {
    final j = joinedChallenges;
    return j.isEmpty ? null : j.first;
  }

  /// Why [id] can't be started right now, or null if it can.
  String? joinBlockedReason(String id) {
    final arc = definition(id);
    final now = DateTime.now();
    if (arc.seasonal && !arc.inSeason(now)) {
      return '${arc.name} opens on ${DateFormat('d MMMM').format(arc.seasonFor(now).start)}. Seasonal arcs can only be done in their season.';
    }
    return null;
  }

  /// Seasonal arcs end with their season, and only one challenge can run
  /// at a time (older data may have several: keep the one furthest along).
  void _enforceOneAtATime() {
    final now = DateTime.now();
    for (final arc in joinedChallenges) {
      if (arc.seasonal && !arc.inSeason(now)) {
        final days = arc.strict ? dayNumber(arc.id) - 1 : completedDays(arc.id);
        _pendingEvents.add(days == 0
            ? '${arc.name} isn\'t in season now, so it was ended. It opens on ${DateFormat('d MMMM').format(arc.seasonFor(now).start)}.'
            : '${arc.name}\'s season is over. You finished with $days days. It comes back on ${DateFormat('d MMMM').format(arc.seasonFor(now).start)}.');
        _end(arc.id);
      }
    }
    final joined = joinedChallenges;
    if (joined.length <= 1) return;
    int progress(ArcDefinition a) => a.strict ? dayNumber(a.id) : completedDays(a.id);
    final keep = joined.reduce((a, b) => progress(b) > progress(a) ? b : a);
    for (final arc in joined) {
      if (arc.id != keep.id) _end(arc.id);
    }
    _pendingEvents.add('You can now do one challenge at a time, so ${keep.name} is your active challenge. You can switch any time from Challenges.');
  }

  void _end(String id) {
    final s = _s(id);
    final run = definition(id).strict ? dayNumber(id) - 1 : completedDays(id);
    if (run > bestRun(id)) s['best'] = run;
    s['joined'] = false;
    s['start'] = '';
    _save(id);
  }

  /// Edited rule lists keep their own copy of the titles; bring the old
  /// alcohol rules in line with the built-in "No smoking" ones.
  void _renameOldRules(String id) {
    final rules = _s(id)['rules'];
    if (rules is! List) return;
    var changed = false;
    for (final r in rules.cast<Map<String, dynamic>>()) {
      if (r['id'] == 'h_alcohol' && r['title'] == 'No alcohol') {
        r['title'] = 'No smoking';
        r['icon'] = Icons.smoke_free_rounded.codePoint;
        changed = true;
      } else if (r['id'] == 'o_eat' && r['title'] == 'Eat well; drink only on social occasions') {
        r['title'] = 'Eat well and cut down on smoking';
        r['icon'] = Icons.smoke_free_rounded.codePoint;
        changed = true;
      }
    }
    if (changed) _save(id);
  }

  static Map<String, dynamic> _deepCopy(Map raw) {
    final m = Map<String, dynamic>.from(raw);
    if (m['done'] is Map) {
      m['done'] = (m['done'] as Map).map((k, v) => MapEntry(k as String, List<String>.from(v as List)));
    }
    if (m['rules'] is List) m['rules'] = (m['rules'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    return m;
  }

  Map<String, dynamic> _s(String id) => _state.putIfAbsent(id, () => <String, dynamic>{});
  void _save(String id) => _box.put(_key(id), _s(id));

  ArcDefinition definition(String id) => allChallenges.firstWhere((a) => a.id == id, orElse: () => arcDefinitions.first);

  /// Creates (or updates) one of the user's own challenges.
  Future<void> saveCustom(ArcDefinition def) async {
    final i = _custom.indexWhere((c) => c.id == def.id);
    i == -1 ? _custom.add(def) : _custom[i] = def;
    await _box.put(_customKey, _custom.map((c) => c.toMap()).toList());
    notifyListeners();
  }

  Future<void> deleteCustom(String id) async {
    _custom.removeWhere((c) => c.id == id);
    _state.remove(id);
    await _box.put(_customKey, _custom.map((c) => c.toMap()).toList());
    await _box.delete(_key(id));
    notifyListeners();
  }

  /// Days with every rule ticked in the current run.
  int completedDays(String id) {
    final ruleIds = rules(id).map((r) => r.id).toSet();
    return _doneMap(id).values.where((d) => ruleIds.isNotEmpty && ruleIds.every(d.contains)).length;
  }

  // --- Reading state ---

  bool isJoined(String id) => _s(id)['joined'] == true;
  bool introSeen(String id) => _s(id)['introSeen'] == true;
  int attempts(String id) => (_s(id)['attempts'] ?? 0) as int;
  int bestRun(String id) => (_s(id)['best'] ?? 0) as int;

  List<ArcRule> rules(String id) {
    final custom = _s(id)['rules'];
    if (custom is List) return custom.map((r) => ArcRule.fromMap(r as Map)).toList();
    // A copy: the built-in list is const and can't be edited in place.
    return List<ArcRule>.of(definition(id).rules);
  }

  Set<String> doneToday(String id) => Set<String>.from((_doneMap(id)[_today]) ?? const <String>[]);

  Map<String, List<String>> _doneMap(String id) {
    final done = _s(id)['done'];
    if (done is Map<String, List<String>>) return done;
    final converted = <String, List<String>>{};
    _s(id)['done'] = converted;
    return converted;
  }

  DateTime? startDate(String id) => DateTime.tryParse((_s(id)['start'] ?? '') as String);

  /// 1-based day of the current run (Day 1 on the day you start).
  int dayNumber(String id) {
    final start = startDate(id);
    if (start == null) return 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(start).inDays + 1;
  }

  bool isTodayComplete(String id) {
    final done = doneToday(id);
    final all = rules(id);
    return all.isNotEmpty && all.every((r) => done.contains(r.id));
  }

  /// Days needed to finish: a seasonal arc runs from the day you start
  /// to the end of its season; others use their set length.
  int targetDays(String id) {
    final def = definition(id);
    if (!def.seasonal) return def.lengthDays;
    final now = DateTime.now();
    final start = startDate(id) ?? DateTime(now.year, now.month, now.day);
    final left = def.seasonFor(start).end.difference(start).inDays + 1;
    return left.clamp(1, def.lengthDays);
  }

  bool isFinished(String id) {
    if (!isJoined(id)) return false;
    final def = definition(id);
    return def.strict ? dayNumber(id) > targetDays(id) : completedDays(id) >= targetDays(id);
  }

  List<String> takePendingEvents() {
    final e = List<String>.from(_pendingEvents);
    _pendingEvents.clear();
    return e;
  }

  // --- Actions ---

  /// Starts (or restarts) a challenge today, ending any other one.
  /// Throws [StateError] if it's out of season.
  Future<void> join(String id) async {
    final blocked = joinBlockedReason(id);
    if (blocked != null) throw StateError(blocked);
    for (final other in joinedChallenges) {
      if (other.id != id) _end(other.id);
    }
    final s = _s(id);
    s['joined'] = true;
    s['start'] = _today;
    s['done'] = <String, List<String>>{};
    s['xpDays'] = <String>[];
    _save(id);
    notifyListeners();
  }

  Future<void> leave(String id) async {
    final s = _s(id);
    s['joined'] = false;
    s['start'] = '';
    _save(id);
    notifyListeners();
  }

  void markIntroSeen(String id) {
    _s(id)['introSeen'] = true;
    _save(id);
  }

  /// Ticks or unticks a rule for today. Completing every rule earns XP once per day.
  Future<void> toggleRule(String id, String ruleId, {bool? value}) async {
    final today = _doneMap(id).putIfAbsent(_today, () => <String>[]);
    final on = value ?? !today.contains(ruleId);
    if (on == today.contains(ruleId)) return;
    on ? today.add(ruleId) : today.remove(ruleId);

    final xpDays = List<String>.from((_s(id)['xpDays'] ?? const <String>[]) as List);
    if (isTodayComplete(id) && !xpDays.contains(_today)) {
      xpDays.add(_today);
      _s(id)['xpDays'] = xpDays;
      await HiveService.addXp(dayCompleteXp);
    }
    _save(id);
    notifyListeners();
  }

  /// Lets automatic sources (like the step counter) tick a rule.
  Future<void> autoComplete(String ruleSuffix) async {
    for (final arc in allChallenges) {
      if (!isJoined(arc.id)) continue;
      for (final r in rules(arc.id)) {
        if (r.id.endsWith(ruleSuffix) && !doneToday(arc.id).contains(r.id)) {
          await toggleRule(arc.id, r.id, value: true);
        }
      }
    }
  }

  Future<void> saveRule(String id, ArcRule rule) async {
    final list = rules(id);
    final i = list.indexWhere((r) => r.id == rule.id);
    i == -1 ? list.add(rule) : list[i] = rule;
    _s(id)['rules'] = list.map((r) => r.toMap()).toList();
    _save(id);
    notifyListeners();
  }

  Future<void> deleteRule(String id, String ruleId) async {
    final list = rules(id)..removeWhere((r) => r.id == ruleId);
    _s(id)['rules'] = list.map((r) => r.toMap()).toList();
    _save(id);
    notifyListeners();
  }

  Future<void> resetRules(String id) async {
    _s(id).remove('rules');
    _save(id);
    notifyListeners();
  }

  /// Strict mode: any past day of the current run with an unchecked rule
  /// restarts the arc today. Finishing the full length keeps the result.
  void _enforceStrictRules() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final arc in allChallenges) {
      // Relaxed (non-strict) challenges just don't count missed days.
      if (!isJoined(arc.id) || !arc.strict) continue;
      final start = startDate(arc.id);
      if (start == null) continue;
      final ruleIds = rules(arc.id).map((r) => r.id).toSet();
      final done = _doneMap(arc.id);
      var completed = 0;
      for (var d = start; d.isBefore(today) && completed < targetDays(arc.id); d = d.add(const Duration(days: 1))) {
        final dayDone = Set<String>.from(done[_fmt(d)] ?? const <String>[]);
        if (!ruleIds.every(dayDone.contains)) {
          final s = _s(arc.id);
          s['attempts'] = attempts(arc.id) + 1;
          if (completed > bestRun(arc.id)) s['best'] = completed;
          s['start'] = _fmt(today);
          s['done'] = <String, List<String>>{};
          s['xpDays'] = <String>[];
          _save(arc.id);
          final msg = '${arc.name}: a rule was missed on ${DateFormat('EEE d MMM').format(d)}, so your run of $completed days ended. Day 1 starts again today. You\'ve got this.';
          _pendingEvents.add(msg);
          NotificationService.showNow(id: 4, title: '🔁 ${arc.name} restarted', body: msg);
          break;
        }
        completed++;
      }
      if (completed > bestRun(arc.id)) {
        _s(arc.id)['best'] = completed;
        _save(arc.id);
      }
    }
  }
}
