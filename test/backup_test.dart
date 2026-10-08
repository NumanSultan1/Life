import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vortextech_appdev_week4/models/habit.dart';
import 'package:vortextech_appdev_week4/services/backup_service.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory tempDir;
  Box settings() => Hive.box(HiveService.settingsBox);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test');
    Hive.init(tempDir.path);
    for (final b in [HiveService.tasksBox, HiveService.habitsBox, HiveService.journalBox, HiveService.goalsBox, HiveService.settingsBox]) {
      await Hive.openBox(b);
    }
    await settings().put('currentUser', 'alice');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('a backup restores into another account and leaves other users alone', () async {
    await HiveService.saveHabit(Habit(id: 'h1', title: 'Read', streak: 4, longestStreak: 9), 'alice');
    await settings().put('alice_xp', 120);
    await settings().put('alice_moodLog', {'2026-10-07': '😊'});
    await HiveService.saveHabit(Habit(id: 'other', title: 'Not mine'), 'bob');

    // Through real JSON, as the file would be.
    final json = jsonDecode(jsonEncode(BackupService.export()));

    await settings().put('currentUser', 'carol');
    await HiveService.saveHabit(Habit(id: 'old', title: 'Replaced'), 'carol');
    final count = await BackupService.restore(json);

    expect(count, greaterThanOrEqualTo(3));
    final habits = HiveService.getHabits('carol');
    expect(habits.map((h) => h.title), ['Read']);
    expect(habits.single.longestStreak, 9);
    expect(settings().get('carol_xp'), 120);
    expect((settings().get('carol_moodLog') as Map)['2026-10-07'], '😊');
    expect(HiveService.getHabits('bob').single.title, 'Not mine');
  });

  test('a file that is not a Life backup is rejected', () async {
    expect(() => BackupService.restore({'hello': 'world'}), throwsFormatException);
  });

  test('an encrypted backup restores with the right password only', () async {
    await settings().put('alice_medicalId', {'blood': 'O+', 'allergies': 'penicillin'});
    final locked = await BackupService.encrypt(BackupService.export(), 'swat-2026');
    final text = jsonEncode(locked);
    expect(text.contains('penicillin'), isFalse);
    expect(BackupService.isEncrypted(jsonDecode(text)), isTrue);

    await expectLater(BackupService.decrypt(jsonDecode(text) as Map, 'wrong-pass'), throwsFormatException);

    final opened = await BackupService.decrypt(jsonDecode(text) as Map, 'swat-2026');
    await settings().put('currentUser', 'carol');
    await BackupService.restore(opened);
    expect((settings().get('carol_medicalId') as Map)['allergies'], 'penicillin');
  });

  test('a tampered encrypted backup is rejected', () async {
    final locked = await BackupService.encrypt(BackupService.export(), 'swat-2026');
    final data = base64Decode(locked['data'] as String)..[0] ^= 0xFF;
    locked['data'] = base64Encode(data);
    await expectLater(BackupService.decrypt(locked, 'swat-2026'), throwsFormatException);
  });
}
