import '../services/daily_xp.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];

  List<Habit> get habits => _habits;
  int get completedTodayCount => _habits.where((h) => h.isCompletedToday).length;
  int get totalHabits => _habits.length;
  double get completionPercentage => totalHabits == 0 ? 0.0 : completedTodayCount / totalHabits;

  HabitProvider() {
    loadHabits();
  }

  static const int freezePrice = 500;
  static const int restorePrice = 700;

  void loadHabits() {
    final user = HiveService.getCurrentUser();
    _habits = HiveService.getHabits(user);
    _runDayRollover(user);
    notifyListeners();
  }

  /// Settles every day since the app was last opened. Each habit-day that
  /// was missed uses one streak freeze automatically (longest streaks are
  /// protected first); when freezes run out the streak resets, and the old
  /// streak is kept so a restore token can bring it back.
  void _runDayRollover(String user) {
    final box = Hive.box(HiveService.settingsBox);
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final lastReset = box.get('${user}_lastResetDate', defaultValue: '') as String;

    if (lastReset.isEmpty) {
      box.put('${user}_lastResetDate', todayStr);
      return;
    }
    if (lastReset == todayStr) return;

    final last = DateTime.tryParse(lastReset) ?? today.subtract(const Duration(days: 1));
    final gap = DateTime(today.year, today.month, today.day).difference(DateTime(last.year, last.month, last.day)).inDays.clamp(1, 3650);

    var freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
    final events = <String>[];
    final order = List<int>.generate(_habits.length, (i) => i)..sort((a, b) => _habits[b].streak.compareTo(_habits[a].streak));

    for (final i in order) {
      final h = _habits[i];
      // The last day the app saw counts if the habit was done; every day
      // in between was missed.
      final missed = (h.isCompletedToday ? 0 : 1) + (gap - 1);
      var streak = h.streak;
      var previous = h.previousStreak;

      if (streak > 0 && missed > 0) {
        if (freezers >= missed) {
          freezers -= missed;
          events.add('❄️ A streak freeze saved your "${h.title}" streak (${h.streak} days)${missed > 1 ? ' for $missed missed days' : ''}.');
        } else {
          previous = streak;
          streak = 0;
          events.add('💔 Your "${h.title}" streak ended at ${h.streak} days. Use a restore token to bring it back.');
        }
      }

      final updated = h.copyWith(isCompletedToday: false, currentCount: 0, streak: streak, previousStreak: previous, isFrozen: false);
      _habits[i] = updated;
      HiveService.saveHabit(updated, user);
      // New day: today's reminder should fire again.
      _syncReminder(updated);
    }

    box.put('${user}_streakFreezers', freezers);
    box.put('${user}_lastResetDate', todayStr);
    if (events.isNotEmpty) {
      final key = '${user}_streakEvents_$todayStr';
      final existing = List<String>.from(box.get(key, defaultValue: <String>[]) as List);
      box.put(key, [...existing, ...events]);
      _pendingEvents.addAll(events);
      final saved = events.where((e) => e.startsWith('❄️')).length;
      NotificationService.showNow(
        id: 3,
        title: saved > 0 ? '❄️ Streak freeze used' : '💔 Streak lost',
        body: events.length == 1 ? events.first.substring(3) : '${events.first.substring(3)} (+${events.length - 1} more)',
      );
    }
  }

  final List<String> _pendingEvents = [];

  /// Streak events from today's rollover not yet shown to the user.
  List<String> takePendingEvents() {
    final events = List<String>.from(_pendingEvents);
    _pendingEvents.clear();
    return events;
  }

  Future<void> addHabit(Habit habit) async {
    final user = HiveService.getCurrentUser();
    _habits.add(habit);
    await HiveService.saveHabit(habit, user);
    await _syncReminder(habit);
    await DailyXp.sync();
    notifyListeners();
  }

  Future<void> toggleHabitCompletion(String id) async {
    final user = HiveService.getCurrentUser();
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _habits[index];
      final newStatus = !h.isCompletedToday;

      int newStreak = h.streak;
      if (newStatus) {
        newStreak = h.streak + 1;
      } else {
        newStreak = h.streak > 0 ? h.streak - 1 : 0;
      }

      final newLongest = newStreak > h.longestStreak ? newStreak : h.longestStreak;
      final updated = h.copyWith(
        isCompletedToday: newStatus,
        streak: newStreak,
        longestStreak: newLongest,
      );
      _habits[index] = updated;
      await HiveService.saveHabit(updated, user);
      await _syncReminder(updated);
      // Today's tasks + habits are worth 50 XP by share done.
      await DailyXp.sync();
      notifyListeners();
    }
  }

  Future<void> incrementHabitCount(String id) async {
    final user = HiveService.getCurrentUser();
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _habits[index];
      final newCount = h.currentCount + 1;
      final isDone = newCount >= h.targetCount;

      int newStreak = h.streak;
      if (isDone && !h.isCompletedToday) {
        newStreak = h.streak + 1;
      }

      final updated = h.copyWith(
        currentCount: newCount,
        isCompletedToday: isDone,
        streak: newStreak,
      );
      _habits[index] = updated;
      await HiveService.saveHabit(updated, user);
      await DailyXp.sync();
      notifyListeners();
    }
  }

  // --- Streak restore & shop ---

  /// Brings back a streak lost to a missed day, keeping any progress made
  /// since. Uses one restore token.
  Future<bool> restoreStreak(String id) async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return false;
    final h = _habits[index];
    if (h.previousStreak <= h.streak) return false;
    final tokens = box.get('${user}_streakRestoreTokens', defaultValue: 1) as int;
    if (tokens <= 0) return false;

    final restored = h.previousStreak + h.streak;
    final updated = h.copyWith(
      streak: restored,
      previousStreak: 0,
      longestStreak: restored > h.longestStreak ? restored : h.longestStreak,
    );
    _habits[index] = updated;
    await HiveService.saveHabit(updated, user);
    await box.put('${user}_streakRestoreTokens', tokens - 1);
    notifyListeners();
    return true;
  }

  Future<bool> buyStreakFreeze() => _buy('${HiveService.getCurrentUser()}_streakFreezers', freezePrice, 2);

  Future<bool> buyRestoreToken() => _buy('${HiveService.getCurrentUser()}_streakRestoreTokens', restorePrice, 1);

  Future<bool> _buy(String key, int price, int defaultCount) async {
    if (!await HiveService.spendXp(price)) return false;
    final box = Hive.box(HiveService.settingsBox);
    await box.put(key, (box.get(key, defaultValue: defaultCount) as int) + 1);
    notifyListeners();
    return true;
  }

  Future<void> deleteHabit(String id) async {
    final user = HiveService.getCurrentUser();
    _habits.removeWhere((h) => h.id == id);
    await HiveService.deleteHabit(id, user);
    await NotificationService.cancel(NotificationService.habitId(id));
    await DailyXp.sync();
    notifyListeners();
  }

  /// Sets (or clears, with null) a habit's daily reminder time.
  Future<void> setReminder(String id, TimeOfDay? time) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -1) return;
    final updated = _habits[index].copyWith(reminderTime: time == null ? '' : formatTimeOfDay(time));
    _habits[index] = updated;
    await HiveService.saveHabit(updated, HiveService.getCurrentUser());
    await _syncReminder(updated);
    notifyListeners();
  }

  /// Daily reminder; once the habit is done today, the next one is tomorrow.
  Future<void> _syncReminder(Habit habit) async {
    final id = NotificationService.habitId(habit.id);
    final time = parseTimeOfDay(habit.reminderTime);
    if (time == null) {
      await NotificationService.cancel(id);
      return;
    }
    await NotificationService.scheduleDaily(
      id: id,
      title: '🔥 Time for "${habit.title}"',
      body: habit.streak > 0 ? 'Keep your ${habit.streak}-day streak going!' : 'Start a new streak today.',
      time: time,
      skipToday: habit.isCompletedToday,
    );
  }

  /// Re-creates every habit's daily reminder (after logging in).
  Future<void> resyncReminders() async {
    for (final h in _habits) {
      await _syncReminder(h);
    }
  }
}
