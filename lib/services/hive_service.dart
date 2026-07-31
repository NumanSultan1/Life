import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';
import '../models/goal.dart';

class HiveService {
  static const String tasksBox = 'tasksBox';
  static const String habitsBox = 'habitsBox';
  static const String journalBox = 'journalBox';
  static const String goalsBox = 'goalsBox';
  static const String settingsBox = 'settingsBox';
  static const String usersBox = 'usersBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(tasksBox);
    await Hive.openBox(habitsBox);
    await Hive.openBox(journalBox);
    await Hive.openBox(goalsBox);
    await Hive.openBox(settingsBox);
    await Hive.openBox(usersBox);

    final sBox = Hive.box(settingsBox);
    if (sBox.get('userName') == null) {
      await sBox.put('userName', 'User');
      await sBox.put('moodToday', '😊');
      await sBox.put('waterIntake', 0);
      await sBox.put('studyMinutesToday', 0);
      await sBox.put('isDark', false);
      await sBox.put('hasSeenOnboarding', false);
      await sBox.put('isLoggedIn', false);
    }
  }

  // --- CRUD Task Helpers ---
  static List<Task> getTasks() {
    final box = Hive.box(tasksBox);
    return box.values.map((e) => Task.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> saveTask(Task task) async {
    final box = Hive.box(tasksBox);
    await box.put(task.id, task.toMap());
  }

  static Future<void> deleteTask(String id) async {
    final box = Hive.box(tasksBox);
    await box.delete(id);
  }

  // --- CRUD Habit Helpers ---
  static List<Habit> getHabits() {
    final box = Hive.box(habitsBox);
    return box.values.map((e) => Habit.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> saveHabit(Habit habit) async {
    final box = Hive.box(habitsBox);
    await box.put(habit.id, habit.toMap());
  }

  static Future<void> deleteHabit(String id) async {
    final box = Hive.box(habitsBox);
    await box.delete(id);
  }

  // --- CRUD Journal Helpers ---
  static List<JournalEntry> getJournalEntries() {
    final box = Hive.box(journalBox);
    return box.values.map((e) => JournalEntry.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> saveJournalEntry(JournalEntry entry) async {
    final box = Hive.box(journalBox);
    await box.put(entry.id, entry.toMap());
  }

  static Future<void> deleteJournalEntry(String id) async {
    final box = Hive.box(journalBox);
    await box.delete(id);
  }

  // --- CRUD Goal Helpers ---
  static List<Goal> getGoals() {
    final box = Hive.box(goalsBox);
    return box.values.map((e) => Goal.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> saveGoal(Goal goal) async {
    final box = Hive.box(goalsBox);
    await box.put(goal.id, goal.toMap());
  }

  static Future<void> deleteGoal(String id) async {
    final box = Hive.box(goalsBox);
    await box.delete(id);
  }
}