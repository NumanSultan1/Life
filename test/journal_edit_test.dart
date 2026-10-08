import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vortextech_appdev_week4/models/journal_entry.dart';
import 'package:vortextech_appdev_week4/providers/journal_provider.dart';
import 'package:vortextech_appdev_week4/screens/tabs/journal_tab.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('journal_edit');
    Hive.init(dir.path);
    await Hive.openBox(HiveService.journalBox);
    await Hive.openBox(HiveService.settingsBox);
    await Hive.box(HiveService.settingsBox).put('currentUser', 'tester');
    await HiveService.saveJournalEntry(JournalEntry(id: 'j1', title: 'adg', content: 'Hello how are you', mood: '😊', date: DateTime(2026, 10, 8, 12, 51)), 'tester');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  testWidgets('a saved entry can be opened, edited and saved', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    late JournalProvider journal;
    await tester.runAsync(() async => journal = JournalProvider());
    await tester.pumpWidget(ChangeNotifierProvider.value(value: journal, child: const MaterialApp(home: Scaffold(body: JournalTab()))));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('adg'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.text('Edit'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Edit'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Edit Reflection'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'adg'), 'A good day');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save Changes'));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 600));

    final e = journal.allEntries.single;
    expect(e.id, 'j1');
    expect(e.title, 'A good day');
    expect(e.date, DateTime(2026, 10, 8, 12, 51));
    expect(Hive.box(HiveService.settingsBox).get('tester_xp'), isNull);
  });
}
