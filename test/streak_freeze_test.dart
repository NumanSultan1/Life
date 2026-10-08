import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vortextech_appdev_week4/models/habit.dart';
import 'package:vortextech_appdev_week4/providers/habit_provider.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory tempDir;
  Box settings() => Hive.box(HiveService.settingsBox);

  Future<void> lastOpened(int daysAgo) =>
      settings().put('tester_lastResetDate', DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysAgo))));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('freeze_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveService.habitsBox);
    await Hive.openBox(HiveService.settingsBox);
    await settings().put('currentUser', 'tester');
    await settings().put('tester_streakFreezers', 2);
    await settings().put('tester_streakRestoreTokens', 1);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('a missed day uses a freeze automatically and keeps the streak', () async {
    await HiveService.saveHabit(Habit(id: 'a', title: 'Walk', streak: 5, longestStreak: 5), 'tester');
    await lastOpened(1);

    final provider = HabitProvider();
    expect(provider.habits.single.streak, 5);
    expect(settings().get('tester_streakFreezers'), 1);
    expect(provider.takePendingEvents().single, contains('freeze saved'));
  });

  test('a habit done yesterday needs no freeze', () async {
    await HiveService.saveHabit(Habit(id: 'a', title: 'Walk', streak: 5, isCompletedToday: true), 'tester');
    await lastOpened(1);

    final provider = HabitProvider();
    expect(provider.habits.single.streak, 5);
    expect(provider.habits.single.isCompletedToday, isFalse);
    expect(settings().get('tester_streakFreezers'), 2);
  });

  test('several missed days each use a freeze; when they run out the streak resets', () async {
    // Opened 3 days ago: "Walk" wasn't done then, so 3 missed days; "Read"
    // was done, so 2 missed days. Longest streak is protected first but
    // needs 3 freezes, so it is lost and "Read" keeps its streak with 2.
    await HiveService.saveHabit(Habit(id: 'a', title: 'Walk', streak: 5), 'tester');
    await HiveService.saveHabit(Habit(id: 'b', title: 'Read', streak: 2, isCompletedToday: true), 'tester');
    await lastOpened(3);

    final provider = HabitProvider();
    final walk = provider.habits.firstWhere((h) => h.id == 'a');
    final read = provider.habits.firstWhere((h) => h.id == 'b');
    expect(walk.streak, 0);
    expect(walk.previousStreak, 5);
    expect(read.streak, 2);
    expect(settings().get('tester_streakFreezers'), 0);
  });

  test('a restore token brings a lost streak back, plus progress since', () async {
    await HiveService.saveHabit(Habit(id: 'a', title: 'Walk', streak: 1, previousStreak: 5, longestStreak: 5), 'tester');
    await lastOpened(0);

    final provider = HabitProvider();
    expect(await provider.restoreStreak('a'), isTrue);
    expect(provider.habits.single.streak, 6);
    expect(settings().get('tester_streakRestoreTokens'), 0);
    expect(await provider.restoreStreak('a'), isFalse);
  });

  test('shop prices come from the XP-to-spend balance, not the level bar', () async {
    // Level 5 with 0 XP in the bar has earned 100+200+300+400 = 1000 XP.
    await settings().put('tester_level', 5);
    await settings().put('tester_xp', 0);
    await lastOpened(0);

    final provider = HabitProvider();
    expect(await provider.buyStreakFreeze(), isTrue);
    expect(HiveService.getXpBank(), 500);
    expect(await provider.buyRestoreToken(), isFalse); // needs 700
    expect(settings().get('tester_level'), 5); // spending never lowers the level
  });
}
