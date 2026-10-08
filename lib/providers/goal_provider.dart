import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../services/hive_service.dart';

class GoalProvider extends ChangeNotifier {
  List<Goal> _goals = [];

  List<Goal> get goals => _goals;
  int get completedCount => _goals.where((g) => g.progress >= 1.0).length;
  List<Goal> get activeGoals => _goals.where((g) => g.progress < 1.0).toList();

  GoalProvider() {
    loadGoals();
  }

  static String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool isCheckedInToday(Goal goal) => goal.lastCheckIn == _today;

  void loadGoals() {
    final user = HiveService.getCurrentUser();
    _goals = HiveService.getGoals(user);
    notifyListeners();
  }

  /// Creates a goal reached after [days] daily check-ins.
  Future<void> addGoal({required String title, String description = '', required int days}) async {
    final goal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      category: 'Personal',
      targetDate: DateTime.now().add(Duration(days: days)),
      dailyStep: 1.0 / days,
    );
    await restoreGoal(goal);
  }

  /// Saves [goal] as-is; also used to undo a delete.
  Future<void> restoreGoal(Goal goal) async {
    _goals.add(goal);
    await HiveService.saveGoal(goal, HiveService.getCurrentUser());
    notifyListeners();
  }

  /// Marks today's work on a goal (or undoes it if already marked).
  /// Returns true when this check-in completed the goal.
  Future<bool> toggleCheckIn(String id) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) return false;
    final g = _goals[index];
    // An achieved goal is final, so its level-up can't be farmed.
    if (g.progress >= 1.0) return false;

    final Goal updated;
    var justCompleted = false;
    if (isCheckedInToday(g)) {
      updated = g.copyWith(
        progress: _round(g.progress - g.dailyStep),
        lastCheckIn: '',
        checkInCount: g.checkInCount > 0 ? g.checkInCount - 1 : 0,
      );
      // Take back the check-in XP so toggling can't farm it
      await HiveService.addXp(-10);
    } else {
      final newProgress = _round(g.progress + g.dailyStep);
      justCompleted = g.progress < 1.0 && newProgress >= 1.0;
      updated = g.copyWith(progress: newProgress, lastCheckIn: _today, checkInCount: g.checkInCount + 1);
      await HiveService.addXp(10);
      // Award 100 XP if the goal has just been completed!
      if (justCompleted) await HiveService.addXp(100);
    }

    _goals[index] = updated;
    await HiveService.saveGoal(updated, HiveService.getCurrentUser());
    notifyListeners();
    return justCompleted;
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await HiveService.deleteGoal(id, HiveService.getCurrentUser());
    notifyListeners();
  }

  static double _round(double v) => double.parse(v.clamp(0.0, 1.0).toStringAsFixed(4));
}
