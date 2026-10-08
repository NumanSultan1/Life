import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Device notifications: task reminders, daily habit reminders, a daily
/// check-in nudge, and instant alerts (e.g. a streak freeze was used).
///
/// Everything is local to the phone; nothing goes through a server.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Ids are derived from item ids so rescheduling replaces, not duplicates.
  static const int dailyCheckInId = 1;
  static int taskId(String id) => 100000 + (id.hashCode & 0x3FFFFFFF) % 100000000;
  static int habitId(String id) => 200000000 + (id.hashCode & 0x3FFFFFFF) % 100000000;
  static int medicineId(String key) => 300000000 + (key.hashCode & 0x3FFFFFFF) % 100000000;

  static const _channel = AndroidNotificationDetails(
    'life_reminders',
    'Reminders',
    channelDescription: 'Task, habit and daily check-in reminders',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_life',
    color: Color(0xFF0B4DBF),
    // Reminders can name medicines or private tasks: when the phone hides
    // sensitive notification content, the text appears only after unlocking.
    visibility: NotificationVisibility.private,
  );
  static const _details = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  static bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Notifications are a nice-to-have: a failure (no plugin in tests, a
  /// permission revoked mid-way) must never break the action that
  /// triggered it.
  static Future<T?> _safely<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('Notification call failed: $e');
      return null;
    }
  }

  static Future<void> init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC offsets, still correct for "in N hours".
    }
    await _safely(() => _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_life'),
            // Permission is asked in context (when the user turns a reminder on).
            iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          ),
        ));
    _ready = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for permission to show notifications (and exact timing on
  /// Android). Returns whether notifications are allowed.
  static Future<bool> requestPermission() async {
    await init();
    if (!_supported) return false;
    return await _safely(_requestPermission) ?? false;
  }

  static Future<bool> _requestPermission() async {
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      if (granted && !(await android.canScheduleExactNotifications() ?? true)) {
        await android.requestExactAlarmsPermission();
      }
      return granted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  static Future<AndroidScheduleMode> _mode() async {
    final exact = await _safely(() async => await _android?.canScheduleExactNotifications() ?? true) ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// One-off reminder at [when] (skipped if it's already in the past).
  static Future<void> scheduleOnce({required int id, required String title, required String body, required DateTime when}) async {
    await init();
    if (!_supported || !when.isAfter(DateTime.now())) return;
    final mode = await _mode();
    await _safely(() => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: _details,
          androidScheduleMode: mode,
        ));
  }

  /// Repeats every day at [time]; with [skipToday] the first one is tomorrow.
  static Future<void> scheduleDaily({required int id, required String title, required String body, required TimeOfDay time, bool skipToday = false}) async {
    await init();
    if (!_supported) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now) || skipToday) next = next.add(const Duration(days: 1));
    if (skipToday && next.difference(now).inHours > 24) next = next.subtract(const Duration(days: 1));
    final mode = await _mode();
    await _safely(() => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: next,
          notificationDetails: _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
        ));
  }

  /// Repeats every week on [weekday] (1 = Monday) at [time].
  static Future<void> scheduleWeekly({required int id, required String title, required String body, required int weekday, required TimeOfDay time}) async {
    await init();
    if (!_supported) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    while (next.weekday != weekday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    final mode = await _mode();
    await _safely(() => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: next,
          notificationDetails: _details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        ));
  }

  /// Shows a notification right now.
  static Future<void> showNow({required int id, required String title, required String body}) async {
    await init();
    if (!_supported) return;
    await _safely(() => _plugin.show(id: id, title: title, body: body, notificationDetails: _details));
  }

  static Future<void> cancel(int id) async {
    await init();
    if (!_supported) return;
    await _safely(() => _plugin.cancel(id: id));
  }

  static Future<void> cancelAll() async {
    await init();
    if (!_supported) return;
    await _safely(() => _plugin.cancelAll());
  }
}

/// "HH:mm" <-> TimeOfDay helpers for storing reminder times.
String formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? parseTimeOfDay(String s) {
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}
