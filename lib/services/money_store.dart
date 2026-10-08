import 'package:hive_flutter/hive_flutter.dart';
import 'hive_service.dart';

/// A cash book ("Personal", "Shop", "2nd"…).
class MoneyAccount {
  final String id, name;

  const MoneyAccount(this.id, this.name);

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  static MoneyAccount fromMap(Map m) => MoneyAccount(m['id'] as String, m['name'] as String);
}

/// One cash in or cash out.
class MoneyEntry {
  final String id, accountId, category, note;
  final bool isIn;
  final double amount;
  final DateTime date;

  const MoneyEntry({required this.id, required this.accountId, required this.isIn, required this.amount, this.category = 'other', this.note = '', required this.date});

  double get signed => isIn ? amount : -amount;

  MoneyEntry copyWith({String? accountId, bool? isIn, double? amount, String? category, String? note, DateTime? date}) => MoneyEntry(
        id: id,
        accountId: accountId ?? this.accountId,
        isIn: isIn ?? this.isIn,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        note: note ?? this.note,
        date: date ?? this.date,
      );

  Map<String, dynamic> toMap() => {'id': id, 'account': accountId, 'in': isIn, 'amount': amount, 'category': category, 'note': note, 'date': date.toIso8601String()};

  static MoneyEntry fromMap(Map m) => MoneyEntry(
        id: m['id'] as String,
        accountId: (m['account'] ?? MoneyStore.mainId) as String,
        isIn: (m['in'] ?? false) as bool,
        amount: (m['amount'] as num).toDouble(),
        category: (m['category'] ?? 'other') as String,
        note: (m['note'] ?? '') as String,
        date: DateTime.parse(m['date'] as String),
      );
}

/// Cash books with cash in/out entries, per user. Older spending (from
/// the first Money screen) moves into a "Main" account once.
class MoneyStore {
  MoneyStore._();

  static const mainId = 'main';
  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _user => HiveService.getCurrentUser();
  static String get _accountsKey => '${_user}_moneyAccounts';
  static String get _entriesKey => '${_user}_moneyEntries';

  static void _migrate() {
    if (_box.get(_accountsKey) != null) return;
    final old = ((_box.get('${_user}_expenses') as List?) ?? const []).map((m) {
      final e = m as Map;
      return MoneyEntry(
        id: e['id'] as String,
        accountId: mainId,
        isIn: false,
        amount: (e['amount'] as num).toDouble(),
        category: (e['category'] ?? 'other') as String,
        note: (e['note'] ?? '') as String,
        date: DateTime.parse(e['date'] as String),
      ).toMap();
    }).toList();
    _box.put(_entriesKey, old);
    _box.put(_accountsKey, [const MoneyAccount(mainId, 'Main').toMap()]);
    final budget = _box.get('${_user}_budget');
    if (budget is num && budget > 0) _box.put('${_user}_moneyBudgets', {mainId: budget});
    _box.delete('${_user}_expenses');
  }

  // --- Accounts ---

  static List<MoneyAccount> get accounts {
    _migrate();
    return ((_box.get(_accountsKey) as List?) ?? const []).map((m) => MoneyAccount.fromMap(m as Map)).toList();
  }

  static MoneyAccount get current {
    final all = accounts;
    final id = _box.get('${_user}_moneyCurrent') as String?;
    return all.firstWhere((a) => a.id == id, orElse: () => all.first);
  }

  static Future<void> setCurrent(String id) => _box.put('${_user}_moneyCurrent', id);

  static Future<MoneyAccount> addAccount(String name) async {
    final a = MoneyAccount('a${DateTime.now().microsecondsSinceEpoch}', name.trim());
    await _box.put(_accountsKey, [...accounts.map((x) => x.toMap()), a.toMap()]);
    await setCurrent(a.id);
    return a;
  }

  static Future<void> renameAccount(String id, String name) =>
      _box.put(_accountsKey, accounts.map((a) => (a.id == id ? MoneyAccount(id, name.trim()) : a).toMap()).toList());

  /// Deletes a book and its entries (the last book can't be deleted).
  static Future<void> deleteAccount(String id) async {
    final rest = accounts.where((a) => a.id != id).toList();
    if (rest.isEmpty) return;
    await _box.put(_accountsKey, rest.map((a) => a.toMap()).toList());
    await _box.put(_entriesKey, _raw().where((m) => m['account'] != id).toList());
    if (current.id == id || _box.get('${_user}_moneyCurrent') == id) await setCurrent(rest.first.id);
  }

  // --- Entries ---

  static List<Map> _raw() {
    _migrate();
    return List<Map>.from((_box.get(_entriesKey) as List?) ?? const []);
  }

  static List<MoneyEntry> entries([String? accountId]) {
    final all = _raw().map(MoneyEntry.fromMap);
    return (accountId == null ? all : all.where((e) => e.accountId == accountId)).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> save(MoneyEntry e) async {
    final list = _raw()..removeWhere((m) => m['id'] == e.id);
    list.add(e.toMap());
    await _box.put(_entriesKey, list);
  }

  static Future<void> delete(String id) async => _box.put(_entriesKey, _raw()..removeWhere((m) => m['id'] == id));

  /// Account balance after each entry, oldest first (like a cash book).
  static Map<String, double> runningBalances(String accountId) {
    final list = entries(accountId).reversed;
    var balance = 0.0;
    return {
      for (final e in list) e.id: balance += e.signed,
    };
  }

  static double balance(String accountId) => entries(accountId).fold(0.0, (a, e) => a + e.signed);

  // --- Settings ---

  static String get currency => _box.get('${_user}_currency', defaultValue: 'Rs') as String;
  static Future<void> setCurrency(String c) => _box.put('${_user}_currency', c);

  static double budget(String accountId) => (((_box.get('${_user}_moneyBudgets') as Map?) ?? const {})[accountId] as num?)?.toDouble() ?? 0;

  static Future<void> setBudget(String accountId, double v) async {
    final m = Map<String, dynamic>.from((_box.get('${_user}_moneyBudgets') as Map?) ?? const {});
    m[accountId] = v;
    await _box.put('${_user}_moneyBudgets', m);
  }
}
