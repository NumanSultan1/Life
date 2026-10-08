import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vortextech_appdev_week4/screens/money_screen.dart';
import 'package:vortextech_appdev_week4/services/hive_service.dart';
import 'package:vortextech_appdev_week4/services/money_store.dart';

void main() {
  late Directory dir;
  Box settings() => Hive.box(HiveService.settingsBox);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('money');
    Hive.init(dir.path);
    await Hive.openBox(HiveService.settingsBox);
    await settings().put('currentUser', 'numan');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  MoneyEntry e(String id, bool isIn, double amount, DateTime date, {String account = MoneyStore.mainId}) =>
      MoneyEntry(id: id, accountId: account, isIn: isIn, amount: amount, date: date);

  test('old spending moves into the Main book once', () async {
    await settings().put('numan_expenses', [
      {'id': 'x1', 'amount': 600, 'category': 'food', 'note': 'fruits', 'date': '2026-07-30T12:40:00.000'},
    ]);
    await settings().put('numan_budget', 50000);
    expect(MoneyStore.accounts.single.name, 'Main');
    final entry = MoneyStore.entries().single;
    expect(entry.note, 'fruits');
    expect(entry.isIn, isFalse);
    expect(MoneyStore.budget(MoneyStore.mainId), 50000);
    expect(settings().get('numan_expenses'), isNull);
  });

  test('running balance works like a cash book', () async {
    final d = DateTime(2026, 7, 30, 12);
    await MoneyStore.save(e('a', true, 10000, d));
    await MoneyStore.save(e('b', false, 400, d.add(const Duration(minutes: 1))));
    await MoneyStore.save(e('c', false, 650, d.add(const Duration(minutes: 2))));
    final r = MoneyStore.runningBalances(MoneyStore.mainId);
    expect(r['a'], 10000);
    expect(r['b'], 9600);
    expect(r['c'], 8950);
    expect(MoneyStore.balance(MoneyStore.mainId), 8950);
    // Newest first in the list.
    expect(MoneyStore.entries(MoneyStore.mainId).first.id, 'c');
  });

  test('several books stay separate; deleting one removes only its entries', () async {
    expect(MoneyStore.accounts.length, 1);
    final shop = await MoneyStore.addAccount('Shop');
    expect(MoneyStore.current.id, shop.id);
    await MoneyStore.save(e('s1', true, 5000, DateTime.now(), account: shop.id));
    await MoneyStore.save(e('m1', false, 300, DateTime.now()));
    expect(MoneyStore.balance(shop.id), 5000);
    expect(MoneyStore.balance(MoneyStore.mainId), -300);

    await MoneyStore.renameAccount(shop.id, '2nd');
    expect(MoneyStore.accounts.last.name, '2nd');

    await MoneyStore.deleteAccount(shop.id);
    expect(MoneyStore.accounts.map((a) => a.id), [MoneyStore.mainId]);
    expect(MoneyStore.entries().map((x) => x.id), ['m1']);
    expect(MoneyStore.current.id, MoneyStore.mainId);
    // The last book can't be deleted.
    await MoneyStore.deleteAccount(MoneyStore.mainId);
    expect(MoneyStore.accounts.length, 1);
  });

  test('the assistant records into the current book', () async {
    final shop = await MoneyStore.addAccount('Shop');
    await addIncome(25000, 'salary');
    await addExpense(800, 'shopping', 'bottle');
    final entries = MoneyStore.entries(shop.id);
    expect(entries.length, 2);
    expect(entries.firstWhere((x) => x.isIn).category, 'salary');
    expect(spentThisMonth().$1, 800);
  });
}
