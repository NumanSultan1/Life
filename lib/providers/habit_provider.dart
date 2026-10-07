import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit.dart';
import '../services/hive_service.dart';

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];

  List<Habit> get habits => _habits;
  int get completedTodayCount => _habits.where((h) => h.isCompletedToday).length;
  int get totalHabits => _habits.length;
  double get completionPercentage => totalHabits == 0 ? 0.0 : completedTodayCount / totalHabits;

  HabitProvider() {
    loadHabits();
  }

  void loadHabits() {
    final user = HiveService.getCurrentUser();
    _habits = HiveService.getHabits(user);

    // Run Midnight Reset Check
    final box = Hive.box(HiveService.settingsBox);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastReset = box.get('${user}_lastResetDate', defaultValue: '') as String;

    if (lastReset.isNotEmpty && lastReset != todayStr) {
      // Midnight Reset Triggered!
      for (int i = 0; i < _habits.length; i++) {
        final h = _habits[i];
        bool updatedIsFrozen = h.isFrozen;
        int updatedStreak = h.streak;

        if (!h.isCompletedToday) {
          if (h.isFrozen) {
            // Shielded by streak freeze!
            updatedIsFrozen = false;
          } else {
            // Missed! Reset streak to 0 but save previous for potential recovery
            updatedStreak = 0;
          }
        }

        final updated = h.copyWith(
          isCompletedToday: false,
          currentCount: 0,
          previousStreak: h.streak, // Store the streak prior to reset
          streak: updatedStreak,
          isFrozen: updatedIsFrozen,
        );

        _habits[i] = updated;
        HiveService.saveHabit(updated, user);
      }
      box.put('${user}_lastResetDate', todayStr);
    } else if (lastReset.isEmpty) {
      box.put('${user}_lastResetDate', todayStr);
    }

    notifyListeners();
  }

  Future<void> addHabit(Habit habit) async {
    final user = HiveService.getCurrentUser();
    _habits.add(habit);
    await HiveService.saveHabit(habit, user);
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
        // Award 15 XP on completing a habit
        await HiveService.addXp(15);
      } else {
        newStreak = h.streak > 0 ? h.streak - 1 : 0;
        // Take back the XP so toggling can't farm it
        await HiveService.addXp(-15);
      }

      final newLongest = newStreak > h.longestStreak ? newStreak : h.longestStreak;
      final updated = h.copyWith(
        isCompletedToday: newStatus,
        streak: newStreak,
        longestStreak: newLongest,
      );
      _habits[index] = updated;
      await HiveService.saveHabit(updated, user);
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
        // Award 15 XP
        await HiveService.addXp(15);
      }

      final updated = h.copyWith(
        currentCount: newCount,
        isCompletedToday: isDone,
        streak: newStreak,
      );
      _habits[index] = updated;
      await HiveService.saveHabit(updated, user);
      notifyListeners();
    }
  }

  // --- Streak Freezer & Restore logic ---
  Future<bool> toggleStreakFreeze(String id) async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _habits[index];
      if (h.isFrozen) {
        // Unfreeze and return the freezer to pool
        final updated = h.copyWith(isFrozen: false);
        _habits[index] = updated;
        await HiveService.saveHabit(updated, user);
        int freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
        await box.put('${user}_streakFreezers', freezers + 1);
        notifyListeners();
        return true;
      } else {
        // Freeze! Requires freezer token
        int freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
        if (freezers > 0) {
          final updated = h.copyWith(isFrozen: true);
          _habits[index] = updated;
          await HiveService.saveHabit(updated, user);
          await box.put('${user}_streakFreezers', freezers - 1);
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }

  Future<bool> restoreStreak(String id) async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _habits[index];
      if (h.streak == 0 && h.previousStreak > 0) {
        int tokens = box.get('${user}_streakRestoreTokens', defaultValue: 2) as int;
        if (tokens > 0) {
          final updated = h.copyWith(
            streak: h.previousStreak,
            previousStreak: 0,
          );
          _habits[index] = updated;
          await HiveService.saveHabit(updated, user);
          await box.put('${user}_streakRestoreTokens', tokens - 1);
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }

  // --- Shop/Economy purchases ---
  Future<bool> buyStreakFreeze() async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    int currentXp = box.get('${user}_xp', defaultValue: 0) as int;
    if (currentXp >= 50) {
      currentXp -= 50;
      await box.put('${user}_xp', currentXp);
      int freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
      await box.put('${user}_streakFreezers', freezers + 1);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> buyRestoreToken() async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    int currentXp = box.get('${user}_xp', defaultValue: 0) as int;
    if (currentXp >= 80) {
      currentXp -= 80;
      await box.put('${user}_xp', currentXp);
      int tokens = box.get('${user}_streakRestoreTokens', defaultValue: 2) as int;
      await box.put('${user}_streakRestoreTokens', tokens + 1);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> deleteHabit(String id) async {
    final user = HiveService.getCurrentUser();
    _habits.removeWhere((h) => h.id == id);
    await HiveService.deleteHabit(id, user);
    notifyListeners();
  }
}
