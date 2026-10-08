import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vortextech_appdev_week4/models/habit.dart';
import 'package:vortextech_appdev_week4/models/task.dart';
import 'package:vortextech_appdev_week4/providers/habit_provider.dart';
import 'package:vortextech_appdev_week4/providers/task_provider.dart';
import 'package:vortextech_appdev_week4/services/daily_xp.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory dir;
  Box settings() => Hive.box(HiveService.settingsBox);
  int xp() => (settings().get('t_level', defaultValue: 1) as int) * 1000 + (settings().get('t_xp', defaultValue: 0) as int);
  int bank() => settings().get('t_xpBank', defaultValue: 0) as int;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('daily_xp');
    Hive.init(dir.path);
    for (final b in [HiveService.tasksBox, HiveService.habitsBox, HiveService.settingsBox]) {
      await Hive.openBox(b);
    }
    await settings().put('currentUser', 't');
    await settings().put('t_lastResetDate', DateFormat('yyyy-MM-dd').format(DateTime.now()));
    await settings().put('t_waterIntake', 0);
    final now = DateTime.now();
    await HiveService.saveTask(Task(id: 'water_drink_task', title: 'Drink water', dueDate: now), 't');
    await HiveService.saveTask(Task(id: 'a', title: 'Call Abu', dueDate: DateTime(now.year, now.month, now.day, 23)), 't');
    await HiveService.saveHabit(Habit(id: 'g', title: 'Gym'), 't');
    await HiveService.saveHabit(Habit(id: 'r', title: 'Read'), 't');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('today is worth 50 XP, earned by share done', () async {
    final tasks = TaskProvider();
    final habits = HabitProvider();
    // 4 items: water task, Call Abu, Gym, Read.
    expect(DailyXp.todayCounts().$2, 4);

    await habits.toggleHabitCompletion('g'); // 1/4 → 13
    expect(DailyXp.earnedToday, 13);
    await tasks.toggleTaskStatus('a'); // 2/4 → 25
    expect(DailyXp.earnedToday, 25);
    expect(bank(), 25);
    await habits.toggleHabitCompletion('r'); // 3/4 → 38
    await tasks.toggleTaskStatus('water_drink_task'); // 4/4 → 50
    expect(DailyXp.earnedToday, 50);
    expect(bank(), 50);

    // Unticking takes it back; ticking again can't add more than 50.
    await habits.toggleHabitCompletion('r');
    expect(DailyXp.earnedToday, 38);
    await habits.toggleHabitCompletion('r');
    await habits.toggleHabitCompletion('r');
    await habits.toggleHabitCompletion('r');
    expect(DailyXp.earnedToday, 50);
    expect(bank(), 50);

    // A new task lowers today's share.
    await tasks.addTask(Task(id: 'b', title: 'Buy milk', dueDate: DateTime.now()));
    expect(DailyXp.earnedToday, 40); // 4/5
    expect(xp(), greaterThan(0));
  });

  test('no tasks or habits means no daily XP', () async {
    await HiveService.deleteTask('a', 't');
    await HiveService.deleteTask('water_drink_task', 't');
    await HiveService.deleteHabit('g', 't');
    await HiveService.deleteHabit('r', 't');
    expect(await DailyXp.sync(), 0);
  });
}
