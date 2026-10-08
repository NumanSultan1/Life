import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'hive_service.dart';

/// Remembers how much of each day was completed, for the weekly chart.
class ProgressHistory {
  ProgressHistory._();

  static String _key(String user) => '${user}_history';
  static String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Saves today's done/total (only writes when it changed).
  static void recordToday(int done, int total) {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final history = Map<String, dynamic>.from(box.get(_key(user), defaultValue: <String, dynamic>{}) as Map);
    final today = _date(DateTime.now());
    final current = history[today];
    if (current is List && current.length == 2 && current[0] == done && current[1] == total) return;
    history[today] = [done, total];
    // Keep roughly a year of history.
    if (history.length > 400) {
      final keys = history.keys.toList()..sort();
      for (final k in keys.take(history.length - 400)) {
        history.remove(k);
      }
    }
    box.put(_key(user), history);
  }

  /// Completion (0..1) for Monday to Sunday of the current week; null for
  /// days with no record (or in the future).
  static List<double?> thisWeek() {
    final user = HiveService.getCurrentUser();
    final history = Map<String, dynamic>.from(Hive.box(HiveService.settingsBox).get(_key(user), defaultValue: <String, dynamic>{}) as Map);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) {
      final entry = history[_date(monday.add(Duration(days: i)))];
      if (entry is! List || entry.length != 2) return null;
      final total = entry[1] as int;
      return total == 0 ? 0.0 : (entry[0] as int) / total;
    });
  }
}
