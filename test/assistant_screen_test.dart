import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vortextech_appdev_week4/assistant/assistant_memory.dart';
import 'package:vortextech_appdev_week4/assistant/assistant_screen.dart';
import 'package:vortextech_appdev_week4/models/habit.dart';
import 'package:vortextech_appdev_week4/providers/activity_provider.dart';
import 'package:vortextech_appdev_week4/providers/habit_provider.dart';
import 'package:vortextech_appdev_week4/providers/journal_provider.dart';
import 'package:vortextech_appdev_week4/providers/task_provider.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

/// Drives the assistant like a user: type, send, check the app's data.
void main() {
  late Directory tempDir;
  late TaskProvider tasks;
  late HabitProvider habits;
  late JournalProvider journal;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('assistant_screen');
    Hive.init(tempDir.path);
    for (final b in [HiveService.tasksBox, HiveService.habitsBox, HiveService.journalBox, HiveService.goalsBox, HiveService.settingsBox]) {
      await Hive.openBox(b);
    }
    await Hive.box(HiveService.settingsBox).put('currentUser', 'tester');
    await HiveService.saveHabit(Habit(id: 'g', title: 'Gym'), 'tester');
    await AssistantMemory.setStyle(const AssistantStyle(speak: false));
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpAssistant(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      tasks = TaskProvider();
      habits = HabitProvider();
      journal = JournalProvider();
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: tasks),
        ChangeNotifierProvider.value(value: habits),
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const AssistantScreen())), child: const Text('open')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.send_rounded));
      await Future.delayed(const Duration(milliseconds: 600));
    });
    // Let the chat scroll down to the newest reply.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('acts on reminders, water and habits, and learns a taught phrase', (tester) async {
    await pumpAssistant(tester);

    await say(tester, 'Remind me to call Abu tomorrow at 6');
    final reminder = tasks.allTasks.firstWhere((t) => t.title == 'Call Abu');
    expect(reminder.hasReminder, isTrue);
    expect(reminder.dueDate.hour, 18);
    expect(find.textContaining('remind you'), findsOneWidget);

    await say(tester, 'I drank 2 glasses of water');
    expect(Hive.box(HiveService.settingsBox).get('tester_waterIntake'), 2);

    await say(tester, 'سبا ماښام ۷ بجې را یاد کړه مور ته زنګ ووهم');
    expect(tasks.allTasks.any((t) => t.title == 'مور ته زنګ ووهم' && t.dueDate.hour == 19), isTrue);
    expect(find.textContaining('در یاد کړم'), findsOneWidget);

    await say(tester, 'done with gym');
    expect(habits.habits.single.isCompletedToday, isTrue);

    // Something it doesn't know: teach it once.
    await say(tester, 'ګډې ته ځم');
    expect(find.text('عادت'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('کار'));
      await Future.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(tasks.allTasks.where((t) => t.title == 'ګډې ته ځم').length, 1);

    // Next time it just does it.
    await say(tester, 'ګډې ته ځم');
    expect(tasks.allTasks.where((t) => t.title == 'ګډې ته ځم').length, 2);
  });

  testWidgets('undo reverses an action and chat highlights go to the journal', (tester) async {
    await pumpAssistant(tester);

    await say(tester, 'add a task buy milk');
    expect(tasks.allTasks.any((t) => t.title == 'Buy milk'), isTrue);
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo').last);
      await Future.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(tasks.allTasks.any((t) => t.title == 'Buy milk'), isFalse);

    await say(tester, 'haha my brother fell in the river while fishing today!');
    await tester.runAsync(() async {
      await tester.tap(find.text('Just chatting'));
      await Future.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await Future.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump(const Duration(seconds: 1));
    final entry = journal.allEntries.firstWhere((e) => e.title.startsWith('Chat highlights'));
    expect(entry.content, contains('fell in the river'));
  });

  testWidgets('replies in the same typed style, and learns meanings', (tester) async {
    await pumpAssistant(tester);

    await say(tester, 'me thek ho tum kese ho');
    expect(find.textContaining('Main bhi theek hoon'), findsOneWidget);

    await say(tester, 'Za kha yama ta sanga ye');
    expect(find.textContaining('Za ham kha yam'), findsOneWidget);

    // Teach a phrase with its English meaning, then use it.
    await say(tester, 'kitab rawra = add a task bring the book');
    expect(find.textContaining('Poh shwam'), findsOneWidget);
    await say(tester, 'kitab rawra');
    expect(tasks.allTasks.any((t) => t.title == 'Bring the book'), isTrue);
    expect(find.textContaining('Kaar me zyat kro'), findsOneWidget);

    await say(tester, 'saba sahar 8 bajy rata yaad kra che mor ta zang wawaham');
    expect(tasks.allTasks.any((t) => t.title == 'Mor ta zang wawaham' && t.dueDate.hour == 8 && t.hasReminder), isTrue);
    expect(find.textContaining('dar yaad kram'), findsOneWidget);
  });

  testWidgets('the screenshot conversation: a new lesson replaces "just chatting" and a taught reply is used', (tester) async {
    await pumpAssistant(tester);

    await say(tester, 'sanga chal de');
    // Didn't know it: offers meanings in Roman Pashto; the user picks "just chatting".
    await tester.runAsync(() async {
      await tester.tap(find.text('Sirf khabare'));
      await Future.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump(const Duration(milliseconds: 300));

    await say(tester, 'sanga chal de means how are you');
    await say(tester, 'sanga chal de');
    expect(find.textContaining('Ta sanga ye?'), findsWidgets);

    await say(tester, 'sanga chal de means how are you and you should reply like za hm kha yama ta sanga ye means that I am fine how are you');
    await say(tester, 'sanga chal de');
    expect(find.text('za hm kha yama ta sanga ye'), findsOneWidget);

    // Keeps the user's style for everyday chat and mirrors "yara".
    await say(tester, 'ta sa kawe yara');
    expect(find.textContaining('Ta sa kawe?'), findsOneWidget);
    await say(tester, 'nan dera stray yam');
    expect(find.textContaining('wa yara'), findsWidgets);
  });
}
