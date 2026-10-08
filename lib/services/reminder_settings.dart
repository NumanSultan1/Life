import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_service.dart';
import 'notification_service.dart';

/// Per-user reminder preferences and their scheduled notifications.
class ReminderSettings {
  ReminderSettings._();

  static const _waterHours = [10, 12, 14, 16, 18, 20];
  static int _waterId(int hour) => 10 + hour;

  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _user => HiveService.getCurrentUser();

  /// Whether the "turn on reminders?" prompt has been answered.
  static bool get prompted => _box.get('${_user}_remindersPrompted', defaultValue: false) as bool;
  static Future<void> markPrompted() => _box.put('${_user}_remindersPrompted', true);

  /// Daily check-in time, or null when turned off.
  static TimeOfDay? get dailyCheckIn => parseTimeOfDay(_box.get('${_user}_dailyReminder', defaultValue: '') as String);

  static Future<void> setDailyCheckIn(TimeOfDay? time) async {
    await _box.put('${_user}_dailyReminder', time == null ? '' : formatTimeOfDay(time));
    await _applyDailyCheckIn();
  }

  static bool get waterReminders => _box.get('${_user}_waterReminders', defaultValue: false) as bool;

  static Future<void> setWaterReminders(bool on) async {
    await _box.put('${_user}_waterReminders', on);
    await _applyWater();
  }

  /// Re-creates every app-level reminder (after login or a permission grant).
  static Future<void> applyAll() async {
    await _applyDailyCheckIn();
    await _applyWater();
  }

  static Future<void> _applyDailyCheckIn() async {
    final time = dailyCheckIn;
    if (time == null) {
      await NotificationService.cancel(NotificationService.dailyCheckInId);
      return;
    }
    await NotificationService.scheduleDaily(
      id: NotificationService.dailyCheckInId,
      title: '✨ Time to check in',
      body: 'Tick off your habits, tasks and goals for today, and keep your streaks alive.',
      time: time,
    );
  }

  static Future<void> _applyWater() async {
    for (final hour in _waterHours) {
      if (waterReminders) {
        await NotificationService.scheduleDaily(
          id: _waterId(hour),
          title: '💧 Water break',
          body: 'Have a glass of water and log it in Life.',
          time: TimeOfDay(hour: hour, minute: 0),
        );
      } else {
        await NotificationService.cancel(_waterId(hour));
      }
    }
  }
}
