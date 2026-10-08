import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'hive_service.dart';

/// Completed focus sessions, by day (minutes), for the weekly review and
/// achievements.
class FocusStore {
  FocusStore._();

  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _key => '${HiveService.getCurrentUser()}_focusLog';

  static Map<String, int> log() => Map<String, int>.from(_box.get(_key, defaultValue: <String, int>{}) as Map);

  static Future<void> addSession(int minutes) async {
    final l = log();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    l[today] = (l[today] ?? 0) + minutes;
    await _box.put(_key, l);
    await _box.put('${HiveService.getCurrentUser()}_focusSessions', sessions + 1);
  }

  static int get sessions => _box.get('${HiveService.getCurrentUser()}_focusSessions', defaultValue: 0) as int;

  static int minutesBetween(DateTime from, DateTime to) {
    var total = 0;
    log().forEach((k, v) {
      final d = DateTime.tryParse(k);
      if (d != null && !d.isBefore(DateTime(from.year, from.month, from.day)) && !d.isAfter(to)) total += v;
    });
    return total;
  }
}
