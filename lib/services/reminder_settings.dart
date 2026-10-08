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

  /// Bedtime wind-down reminder, or null when off.
  static TimeOfDay? get bedtime => parseTimeOfDay(_box.get('${_user}_bedtime', defaultValue: '') as String);

  static Future<void> setBedtime(TimeOfDay? time) async {
    await _box.put('${_user}_bedtime', time == null ? '' : formatTimeOfDay(time));
    await _applyBedtime();
  }

  static bool get weeklyReview => _box.get('${_user}_weeklyReviewReminder', defaultValue: true) as bool;

  static Future<void> setWeeklyReview(bool on) async {
    await _box.put('${_user}_weeklyReviewReminder', on);
    await _applyWeekly();
  }

  /// Re-creates every app-level reminder (after login or a permission grant).
  static Future<void> applyAll() async {
    await _applyDailyCheckIn();
    await _applyWater();
    await _applyBedtime();
    await _applyWeekly();
  }

  static Future<void> _applyBedtime() async {
    final t = bedtime;
    if (t == null) return NotificationService.cancel(30);
    await NotificationService.scheduleDaily(
      id: 30,
      title: '🌙 Time to wind down',
      body: 'Screens off soon. A good night\'s sleep makes tomorrow easier.',
      time: t,
    );
  }

  static Future<void> _applyWeekly() async {
    if (!weeklyReview || dailyCheckIn == null) return NotificationService.cancel(31);
    await NotificationService.scheduleWeekly(
      id: 31,
      title: '📅 Your week in review',
      body: 'See how your week went and set one focus for next week.',
      weekday: DateTime.sunday,
      time: const TimeOfDay(hour: 19, minute: 0),
    );
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
