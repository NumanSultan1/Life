import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'hive_service.dart';

/// Today's tasks and habits are worth [max] XP together, earned by the
/// share that's done: 3 of 4 done → 38 XP, all done → 50 XP. Every tick,
/// untick, add or delete recalculates it and only the difference is added
/// or taken back, so nothing can be counted twice. Past days keep what
/// they earned.
class DailyXp {
  DailyXp._();

  static const max = 50;

  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _key => '${HiveService.getCurrentUser()}_dayXp';
  static String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Done / total of today's tasks and habits.
  static (int, int) todayCounts() {
    final user = HiveService.getCurrentUser();
    final now = DateTime.now();
    final tasks = Hive.isBoxOpen(HiveService.tasksBox) ? HiveService.getTasks(user).where((t) => t.isForDay(now)).toList() : const [];
    final habits = Hive.isBoxOpen(HiveService.habitsBox) ? HiveService.getHabits(user) : const [];
    final done = tasks.where((t) => t.isDoneOn(now)).length + habits.where((h) => h.isCompletedToday).length;
    return (done, tasks.length + habits.length);
  }

  static int target(int done, int total) => total == 0 ? 0 : (max * done / total).round().clamp(0, max);

  /// XP already given today.
  static int get earnedToday => ((((_box.get(_key) as Map?) ?? const {})[_today]) as int?) ?? 0;

  /// Brings today's XP in line with what's done. Returns the change.
  static Future<int> sync() async {
    if (HiveService.getCurrentUser().isEmpty) return 0;
    final (done, total) = todayCounts();
    final goal = target(done, total);
    // First run after updating: today's XP was already given the old way
    // (per task/habit), so just record today without adding more.
    if (_box.get(_key) == null && _box.get('${HiveService.getCurrentUser()}_xp') != null) {
      await _box.put(_key, {_today: goal});
      return 0;
    }
    final delta = goal - earnedToday;
    if (delta == 0) return 0;
    await HiveService.addXp(delta);
    // Only today's figure is needed; earlier days are settled.
    await _box.put(_key, {_today: goal});
    return delta;
  }
}
