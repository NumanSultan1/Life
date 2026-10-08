import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/arc_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/task_provider.dart';
import 'focus_store.dart';
import 'hive_service.dart';

/// Read-only history across the app, for Insights, the weekly review and
/// achievements.
class LifeStats {
  final BuildContext context;

  LifeStats(this.context);

  static final _fmt = DateFormat('yyyy-MM-dd');
  static String key(DateTime d) => _fmt.format(d);
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  Box get _box => Hive.box(HiveService.settingsBox);
  String get _user => HiveService.getCurrentUser();
  Map<String, dynamic> _map(String name) => Map<String, dynamic>.from(_box.get('${_user}_$name', defaultValue: <String, dynamic>{}) as Map);

  static const moodScore = {'😄': 5, '😊': 4, '😐': 3, '😔': 2, '😭': 1};

  Map<String, String> get moods => _map('moodLog').map((k, v) => MapEntry(k, v as String));
  Map<String, int> get steps => _map('stepHistory').map((k, v) => MapEntry(k, v as int));
  Map<String, int> get sleepMinutes => _map('sleepLog').map((k, v) => MapEntry(k, v as int));
  Map<String, int> get focusMinutes => FocusStore.log();

  /// Share of planned things done each day (from the Home ring).
  Map<String, double> get dayProgress => _map('history').map((k, v) {
        final l = v as List;
        final total = l[1] as int;
        return MapEntry(k, total == 0 ? 0.0 : (l[0] as int) / total);
      });

  int get stepGoal => _box.get('${_user}_stepGoal', defaultValue: 8000) as int;
  int get level => _box.get('${_user}_level', defaultValue: 1) as int;

  TaskProvider get tasks => Provider.of<TaskProvider>(context, listen: false);
  HabitProvider get habits => Provider.of<HabitProvider>(context, listen: false);
  GoalProvider get goals => Provider.of<GoalProvider>(context, listen: false);
  JournalProvider get journal => Provider.of<JournalProvider>(context, listen: false);
  ArcProvider get arcs => Provider.of<ArcProvider>(context, listen: false);

  /// Days from [from] to [to] inclusive.
  static List<DateTime> days(DateTime from, DateTime to) {
    final out = <DateTime>[];
    for (var d = day(from); !d.isAfter(day(to)); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  int tasksDoneBetween(DateTime from, DateTime to) {
    final range = days(from, to).map(key).toSet();
    var n = 0;
    for (final t in tasks.allTasks) {
      if (t.repeats) {
        n += t.completedDates.where(range.contains).length;
      } else if (t.isCompleted && range.contains(key(t.dueDate))) {
        n++;
      }
    }
    return n;
  }

  int journalBetween(DateTime from, DateTime to) =>
      journal.allEntries.where((e) => !day(e.date).isBefore(day(from)) && !day(e.date).isAfter(day(to))).length;

  int sumBetween(Map<String, int> m, DateTime from, DateTime to) => days(from, to).fold(0, (n, d) => n + (m[key(d)] ?? 0));

  double? averageMood(Iterable<String> dayKeys) {
    final scores = dayKeys.map((k) => moodScore[moods[k]]).whereType<int>().toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}
