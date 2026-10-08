import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:vortextech_appdev_week4/data/arcs.dart';
import 'package:vortextech_appdev_week4/providers/arc_provider.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory tempDir;
  Box settings() => Hive.box(HiveService.settingsBox);
  String day(int daysAgo) => DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysAgo)));
  final winterRules = arcDefinitions.firstWhere((a) => a.id == 'winter').rules.map((r) => r.id).toList();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_test');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveService.settingsBox);
    await settings().put('currentUser', 'tester');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('joining starts at Day 1 and finishing every rule earns XP once', () async {
    final provider = ArcProvider();
    await provider.join('winter');
    expect(provider.dayNumber('winter'), 1);

    for (final id in winterRules) {
      await provider.toggleRule('winter', id);
    }
    expect(provider.isTodayComplete('winter'), isTrue);
    expect(settings().get('tester_xp'), ArcProvider.dayCompleteXp);

    // Untick and re-tick the last rule: no second payout today.
    await provider.toggleRule('winter', winterRules.last);
    await provider.toggleRule('winter', winterRules.last);
    expect(settings().get('tester_xp'), ArcProvider.dayCompleteXp);
  });

  test('complete past days keep the run going', () async {
    await settings().put('tester_arc_winter', {
      'joined': true,
      'start': day(2),
      'done': {day(2): winterRules, day(1): winterRules},
    });
    final provider = ArcProvider();
    expect(provider.dayNumber('winter'), 3);
    expect(provider.bestRun('winter'), 2);
    expect(provider.takePendingEvents(), isEmpty);
  });

  test('a missed rule on any past day restarts the arc at Day 1', () async {
    await settings().put('tester_arc_winter', {
      'joined': true,
      'start': day(3),
      'done': {
        day(3): winterRules,
        day(2): winterRules.sublist(1), // one rule missed
        day(1): winterRules,
      },
    });
    final provider = ArcProvider();
    expect(provider.dayNumber('winter'), 1);
    expect(provider.attempts('winter'), 1);
    expect(provider.bestRun('winter'), 1);
    expect(provider.takePendingEvents().single, contains('Day 1 starts again'));
  });

  test('rules can be edited, added and reset', () async {
    final provider = ArcProvider();
    await provider.saveRule('winter', const ArcRule(id: 'c_1', title: '50 push-ups'));
    expect(provider.rules('winter').last.title, '50 push-ups');
    await provider.deleteRule('winter', 'w_read');
    expect(provider.rules('winter').any((r) => r.id == 'w_read'), isFalse);
    await provider.resetRules('winter');
    expect(provider.rules('winter').length, winterRules.length);
  });

  test('custom challenges can be created, joined and deleted', () async {
    final provider = ArcProvider();
    await provider.saveCustom(ArcDefinition.fromMap({
      'id': 'custom_1',
      'name': 'No Sugar November',
      'days': 30,
      'strict': false,
      'rules': [const ArcRule(id: 'r1', title: 'No sugar').toMap()],
    }));
    expect(provider.allChallenges.any((a) => a.id == 'custom_1'), isTrue);

    await provider.join('custom_1');
    await provider.toggleRule('custom_1', 'r1');
    expect(provider.completedDays('custom_1'), 1);

    // Reloading keeps it.
    final reloaded = ArcProvider();
    expect(reloaded.definition('custom_1').name, 'No Sugar November');

    await reloaded.deleteCustom('custom_1');
    expect(reloaded.allChallenges.any((a) => a.id == 'custom_1'), isFalse);
  });

  test('relaxed challenges do not restart on a missed day', () async {
    await settings().put('tester_customChallenges', [
      {'id': 'custom_2', 'name': 'Relaxed', 'days': 10, 'strict': false, 'rules': [const ArcRule(id: 'r1', title: 'Walk').toMap()]},
    ]);
    await settings().put('tester_arc_custom_2', {
      'joined': true,
      'start': day(3),
      'done': {day(3): ['r1'], day(1): ['r1']}, // day(2) missed
    });
    final provider = ArcProvider();
    expect(provider.dayNumber('custom_2'), 4);
    expect(provider.completedDays('custom_2'), 2);
    expect(provider.attempts('custom_2'), 0);
  });

  test('every built-in challenge is well formed', () {
    expect(arcDefinitions.map((a) => a.id).toSet().length, arcDefinitions.length);
    for (final a in arcDefinitions) {
      expect(a.rules, isNotEmpty, reason: a.name);
      expect(a.lengthDays, greaterThan(0), reason: a.name);
      expect(a.rules.map((r) => r.id).toSet().length, a.rules.length, reason: a.name);
    }
    expect(arcDefinitions.firstWhere((a) => a.id == 'hard75').lengthDays, 75);
  });

  test('only one challenge runs at a time', () async {
    final provider = ArcProvider();
    await provider.join('hard75');
    await provider.join('soft75');
    expect(provider.isJoined('hard75'), isFalse);
    expect(provider.activeChallenge?.id, 'soft75');
  });

  test('a seasonal arc cannot be started out of season', () async {
    final provider = ArcProvider();
    final closed = arcDefinitions.firstWhere((a) => a.seasonal && !a.inSeason(DateTime.now()));
    expect(provider.joinBlockedReason(closed.id), isNotNull);
    expect(() => provider.join(closed.id), throwsStateError);
    expect(provider.isJoined(closed.id), isFalse);
  });

  test('old data with several challenges keeps only one', () async {
    for (final id in ['hard75', 'soft75']) {
      await settings().put('tester_arc_$id', {'joined': true, 'start': DateFormat('yyyy-MM-dd').format(DateTime.now())});
    }
    final provider = ArcProvider();
    expect(provider.joinedChallenges.length, 1);
    expect(provider.takePendingEvents(), isNotEmpty);
  });
}
