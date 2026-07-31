import 'package:flutter/material.dart';
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
    _habits = HiveService.getHabits();
    notifyListeners();
  }

  Future<void> addHabit(Habit habit) async {
    _habits.add(habit);
    await HiveService.saveHabit(habit);
    notifyListeners();
  }

  Future<void> toggleHabitCompletion(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _habits[index];
      final newStatus = !h.isCompletedToday;
      final newStreak = newStatus ? h.streak + 1 : (h.streak > 0 ? h.streak - 1 : 0);
      final newLongest = newStreak > h.longestStreak ? newStreak : h.longestStreak;
      final updated = h.copyWith(
        isCompletedToday: newStatus,
        streak: newStreak,
        longestStreak: newLongest,
      );
      _habits[index] = updated;
      await HiveService.saveHabit(updated);
      notifyListeners();
    }
  }

  Future<void> incrementHabitCount(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      final h = _habits[index];
      final newCount = h.currentCount + 1;
      final isDone = newCount >= h.targetCount;
      final updated = h.copyWith(
        currentCount: newCount,
        isCompletedToday: isDone,
        streak: isDone && !h.isCompletedToday ? h.streak + 1 : h.streak,
      );
      _habits[index] = updated;
      await HiveService.saveHabit(updated);
      notifyListeners();
    }
  }

  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    await HiveService.deleteHabit(id);
    notifyListeners();
  }
}
