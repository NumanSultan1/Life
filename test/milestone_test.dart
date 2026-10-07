import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vortextech_appdev_week4/models/habit.dart';
import 'package:vortextech_appdev_week4/providers/habit_provider.dart';
import 'package:vortextech_appdev_week4/screens/tabs/habits_tab.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('milestone_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveService.habitsBox);
    await Hive.openBox(HiveService.settingsBox);
    await Hive.box(HiveService.settingsBox).put('currentUser', 'tester');
    // Pre-set today's reset marker so HabitProvider doesn't write to Hive
    // while the widget test's fake-async zone is active.
    await Hive.box(HiveService.settingsBox).put('tester_lastResetDate', DateFormat('yyyy-MM-dd').format(DateTime.now()));
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('completing a habit that reaches a milestone shows the celebration', (tester) async {
    await tester.runAsync(() => HiveService.saveHabit(Habit(id: '1', title: 'Read', streak: 2, longestStreak: 2), 'tester'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: HabitProvider(),
        child: const MaterialApp(home: Scaffold(body: HabitsTab())),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.local_fire_department_rounded).last);
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('DAY STREAK'), findsOneWidget);
    expect(find.textContaining('You just hit a 3 days milestone!'), findsOneWidget);
  });

  testWidgets('completing a habit that is not a milestone shows nothing', (tester) async {
    await tester.runAsync(() => HiveService.saveHabit(Habit(id: '1', title: 'Read', streak: 3, longestStreak: 3), 'tester'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: HabitProvider(),
        child: const MaterialApp(home: Scaffold(body: HabitsTab())),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.local_fire_department_rounded).last);
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('DAY STREAK'), findsNothing);
  });
}
