import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vortextech_appdev_week4/assistant/assistant_engine.dart';
import 'package:vortextech_appdev_week4/assistant/assistant_memory.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('assistant_memory');
    Hive.init(tempDir.path);
    await Hive.openBox(HiveService.settingsBox);
    await Hive.box(HiveService.settingsBox).put('currentUser', 'tester');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('a taught Pashto phrase is understood next time, even with extra words', () async {
    await AssistantMemory.teach('ګډې ته ځم', const LearnedMeaning('habit', {'habit': 'Gym'}));
    expect(AssistantMemory.match('ګډې ته ځم')?.$2.params['habit'], 'Gym');
    expect(AssistantMemory.match('نن ګډې ته ځم')?.$2.type, 'habit');
    expect(AssistantMemory.match('بازار ته ځم'), isNull);
  });

  test('word fixes from an edit are applied to what speech heard', () async {
    await AssistantMemory.learnFromEdit('remind me to call a boo at 6', 'remind me to call Abu at 6');
    expect(AssistantMemory.applyCorrections('call a boo tomorrow'), 'call Abu tomorrow');
    await AssistantMemory.learnFromEdit('زما ورور سلیم دي', 'زما ورور سلیم دی');
    expect(AssistantMemory.applyCorrections('سلیم دي'), 'سلیم دی');
  });

  test('facts are stored, found by topic, and feed Pashto speech hints', () async {
    await AssistantMemory.addFact('Abu is my father');
    await AssistantMemory.addFact('I play cricket on Fridays');
    expect(AssistantMemory.relevantFacts('call my father'), ['Abu is my father']);
    expect(AssistantMemory.speechHints(), contains('Abu'));
    await AssistantMemory.removeFact('Abu is my father');
    expect(AssistantMemory.facts.length, 1);
  });

  test('style changes persist', () async {
    await AssistantMemory.setStyle(AssistantMemory.style.copyWith(name: 'Numan', short: true));
    expect(AssistantMemory.style.name, 'Numan');
    expect(AssistantMemory.style.short, isTrue);
    expect(AssistantMemory.style.speak, isTrue);
  });

  test('highlights keep funny, amazing or important lines only', () {
    final picked = pickHighlights([
      'ok',
      'the weather is normal today',
      'haha my brother fell in the river while fishing!',
      'زما امتحان ډېر ښه شو، ډېر خوشحاله یم',
      'yaar aaj cricket mein bohat maza aaya, last ball pe six!',
    ]);
    expect(picked.length, 3);
    expect(picked, isNot(contains('the weather is normal today')));
  });
}
