import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vortextech_appdev_week4/services/secure_boxes.dart';

void main() {
  late Directory dir;
  late Map<String, String> keystore;
  final cipher = HiveAesCipher(List<int>.generate(32, (i) => i * 7 % 256));

  Future<String?> read(String k) async => keystore[k];
  Future<void> write(String k, String v) async => keystore[k] = v;
  Future<void> open(String name) => SecureBoxes.openBox(name, dir: dir.path, cipher: cipher, read: read, write: write);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('secure_boxes');
    keystore = {};
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> seedPlain() async {
    final box = await Hive.openBox('journalBox');
    await box.put('numan_1', {'title': 'Secret diary', 'content': 'My blood group is O+'});
    await box.put('count', 3);
    await box.close();
  }

  test('existing plain data is converted, kept, and no longer readable on disk', () async {
    await seedPlain();
    expect(File('${dir.path}/journalbox.hive').readAsBytesSync(), containsAllInOrder(utf8.encode('Secret diary')));

    await open('journalBox');
    final box = Hive.box('journalBox');
    expect((box.get('numan_1') as Map)['content'], 'My blood group is O+');
    expect(box.get('count'), 3);
    expect(keystore['enc_journalBox'], 'v1');
    await box.close();

    final raw = utf8.decode(File('${dir.path}/journalbox.hive').readAsBytesSync(), allowMalformed: true);
    expect(raw.contains('Secret diary'), isFalse);
    expect(raw.contains('blood group'), isFalse);
    expect(File('${dir.path}/journalbox.hive.premigration').existsSync(), isFalse);

    // Reopening (next app start) reads the same data.
    await open('journalBox');
    expect((Hive.box('journalBox').get('numan_1') as Map)['title'], 'Secret diary');
  });

  test('a conversion interrupted after deleting the plain file is recovered', () async {
    await seedPlain();
    // Simulate a crash: the safety copy exists, the box file is gone,
    // and the "converted" marker was never written.
    final file = File('${dir.path}/journalbox.hive');
    await file.copy('${file.path}.premigration');
    await file.delete();

    await open('journalBox');
    expect((Hive.box('journalBox').get('numan_1') as Map)['title'], 'Secret diary');
    expect(File('${file.path}.premigration').existsSync(), isFalse);
  });

  test('a new install starts with an empty encrypted box', () async {
    await open('settingsBox');
    final box = Hive.box('settingsBox');
    expect(box.isEmpty, isTrue);
    await box.put('isDark', true);
    await box.close();
    await open('settingsBox');
    expect(Hive.box('settingsBox').get('isDark'), isTrue);
  });
}
