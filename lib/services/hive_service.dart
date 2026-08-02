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

  // --- Current User Helpers ---
  static String getCurrentUser() {
    final box = Hive.box(settingsBox);
    return box.get('currentUser', defaultValue: 'User') as String;
  }

  static Future<void> setCurrentUser(String userName) async {
    final box = Hive.box(settingsBox);
    await box.put('currentUser', userName);
    await initUserIfNeeded(userName);
  }

  static Future<void> initUserIfNeeded(String userName) async {
    if (userName.isEmpty) return;
    final box = Hive.box(settingsBox);
    if (box.get('${userName}_level') == null) {
      await box.put('${userName}_level', 1);
      await box.put('${userName}_xp', 0);
      await box.put('${userName}_moodToday', '😊');
      await box.put('${userName}_waterIntake', 0);
      await box.put('${userName}_studyMinutesToday', 0);
      await box.put('${userName}_streakFreezers', 2);
      await box.put('${userName}_streakRestoreTokens', 2);
      await box.put('${userName}_lastResetDate', '');
    }
  }

  // --- XP Gamification Helpers ---
  static Future<void> addXp(int xpAmount) async {
    final user = getCurrentUser();
    if (user.isEmpty) return;
    final box = Hive.box(settingsBox);
    int currentXp = box.get('${user}_xp', defaultValue: 0) as int;
    int currentLevel = box.get('${user}_level', defaultValue: 1) as int;

    currentXp += xpAmount;
    int xpNeeded = currentLevel * 100;

    while (currentXp >= xpNeeded) {
      currentXp -= xpNeeded;
      currentLevel += 1;
      xpNeeded = currentLevel * 100;
    }

    await box.put('${user}_xp', currentXp);
    await box.put('${user}_level', currentLevel);
  }

  // --- CRUD Task Helpers ---
  static List<Task> getTasks(String userName) {
    final box = Hive.box(tasksBox);
    final list = <Task>[];
    for (var key in box.keys) {
      if (key.toString().startsWith('${userName}_')) {
        final val = box.get(key);
        if (val != null) {
          list.add(Task.fromMap(Map<String, dynamic>.from(val)));
        }
      }
    }
    return list;
  }

  static Future<void> saveTask(Task task, String userName) async {
    final box = Hive.box(tasksBox);
    await box.put('${userName}_${task.id}', task.toMap());
  }

  static Future<void> deleteTask(String id, String userName) async {
    final box = Hive.box(tasksBox);
    await box.delete('${userName}_$id');
  }

  // --- CRUD Habit Helpers ---
  static List<Habit> getHabits(String userName) {
    final box = Hive.box(habitsBox);
    final list = <Habit>[];
    for (var key in box.keys) {
      if (key.toString().startsWith('${userName}_')) {
        final val = box.get(key);
        if (val != null) {
          list.add(Habit.fromMap(Map<String, dynamic>.from(val)));
        }
      }
    }
    return list;
  }

  static Future<void> saveHabit(Habit habit, String userName) async {
    final box = Hive.box(habitsBox);
    await box.put('${userName}_${habit.id}', habit.toMap());
  }

  static Future<void> deleteHabit(String id, String userName) async {
    final box = Hive.box(habitsBox);
    await box.delete('${userName}_$id');
  }

  // --- CRUD Journal Helpers ---
  static List<JournalEntry> getJournalEntries(String userName) {
    final box = Hive.box(journalBox);
    final list = <JournalEntry>[];
    for (var key in box.keys) {
      if (key.toString().startsWith('${userName}_')) {
        final val = box.get(key);
        if (val != null) {
          list.add(JournalEntry.fromMap(Map<String, dynamic>.from(val)));
        }
      }
    }
    return list;
  }

  static Future<void> saveJournalEntry(JournalEntry entry, String userName) async {
    final box = Hive.box(journalBox);
    await box.put('${userName}_${entry.id}', entry.toMap());
  }

  static Future<void> deleteJournalEntry(String id, String userName) async {
    final box = Hive.box(journalBox);
    await box.delete('${userName}_$id');
  }

  // --- CRUD Goal Helpers ---
  static List<Goal> getGoals(String userName) {
    final box = Hive.box(goalsBox);
    final list = <Goal>[];
    for (var key in box.keys) {
      if (key.toString().startsWith('${userName}_')) {
        final val = box.get(key);
        if (val != null) {
          list.add(Goal.fromMap(Map<String, dynamic>.from(val)));
        }
      }
    }
    return list;
  }

  static Future<void> saveGoal(Goal goal, String userName) async {
    final box = Hive.box(goalsBox);
    await box.put('${userName}_${goal.id}', goal.toMap());
  }

  static Future<void> deleteGoal(String id, String userName) async {
    final box = Hive.box(goalsBox);
    await box.delete('${userName}_$id');
  }
}
