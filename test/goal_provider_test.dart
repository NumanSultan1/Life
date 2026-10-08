import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vortextech_appdev_week4/models/goal.dart';
import 'package:vortextech_appdev_week4/providers/goal_provider.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory tempDir;

  int xp() => Hive.box(HiveService.settingsBox).get('tester_xp', defaultValue: 0) as int;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('goal_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveService.goalsBox);
    await Hive.openBox(HiveService.settingsBox);
    await Hive.box(HiveService.settingsBox).put('currentUser', 'tester');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('a 20-day goal moves 5% per daily check-in', () async {
    final provider = GoalProvider();
    await provider.addGoal(title: 'Run a 5K', days: 20);
    final goal = provider.goals.single;
    expect(goal.dailyStep, closeTo(0.05, 1e-9));
    expect(goal.checkInsLeft, 20);

    await provider.toggleCheckIn(goal.id);
    final checked = provider.goals.single;
    expect(checked.progress, closeTo(0.05, 1e-9));
    expect(provider.isCheckedInToday(checked), isTrue);
    expect(checked.checkInsLeft, 19);
    expect(xp(), 10);
  });

  test('undoing a check-in restores progress and takes back the XP', () async {
    final provider = GoalProvider();
    await provider.addGoal(title: 'Read', days: 10);
    final id = provider.goals.single.id;

    await provider.toggleCheckIn(id);
    await provider.toggleCheckIn(id);

    final goal = provider.goals.single;
    expect(goal.progress, 0);
    expect(provider.isCheckedInToday(goal), isFalse);
    expect(goal.checkInCount, 0);
    expect(xp(), 0);
  });

  test('the final check-in completes the goal for good', () async {
    final provider = GoalProvider();
    await provider.restoreGoal(Goal(id: 'g', title: 'Almost', targetDate: DateTime.now(), progress: 0.95, dailyStep: 0.05));

    expect(await provider.toggleCheckIn('g'), isTrue);
    expect(provider.goals.single.progress, 1.0);
    // 10 (check-in) + 100 (bonus) = 110 XP: level 2 with 10 XP left over.
    expect(Hive.box(HiveService.settingsBox).get('tester_level'), 2);
    expect(xp(), 10);

    // An achieved goal can't be undone, so the bonus can't be farmed.
    expect(await provider.toggleCheckIn('g'), isFalse);
    expect(provider.goals.single.progress, 1.0);
    expect(xp(), 10);
  });

  test('goals saved before day-based tracking get a step from their target date', () {
    final goal = Goal.fromMap({
      'id': 'old',
      'title': 'Old goal',
      'progress': 0.2,
      'targetDate': DateTime.now().add(const Duration(days: 40, hours: 1)).toIso8601String(),
    });
    expect(goal.dailyStep, closeTo(0.8 / 40, 1e-9));
    expect(goal.checkInsLeft, 40);
  });
}
