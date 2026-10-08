import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/money_store.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';

class _Category {
  final String id, label;
  final IconData icon;
  final Color color;

  const _Category(this.id, this.label, this.icon, this.color);
}

const _outCategories = [
  _Category('food', 'Food', Icons.restaurant_rounded, AppColors.warning),
  _Category('transport', 'Transport', Icons.directions_bus_rounded, AppColors.sky),
  _Category('bills', 'Bills', Icons.receipt_long_rounded, AppColors.royal),
  _Category('shopping', 'Shopping', Icons.shopping_bag_rounded, AppColors.pink),
  _Category('health', 'Health', Icons.local_hospital_rounded, AppColors.danger),
  _Category('family', 'Family', Icons.family_restroom_rounded, AppColors.success),
  _Category('education', 'Education', Icons.school_rounded, AppColors.violet),
  _Category('other', 'Other', Icons.more_horiz_rounded, AppColors.textSecondary),
];

const _inCategories = [
  _Category('salary', 'Salary', Icons.work_rounded, AppColors.success),
  _Category('business', 'Business', Icons.storefront_rounded, AppColors.royal),
  _Category('sale', 'Sale', Icons.sell_rounded, AppColors.sky),
  _Category('gift', 'Gift', Icons.card_giftcard_rounded, AppColors.pink),
  _Category('loan', 'Loan back', Icons.handshake_rounded, AppColors.violet),
  _Category('other_in', 'Other', Icons.more_horiz_rounded, AppColors.textSecondary),
];

_Category _cat(String id) => [..._outCategories, ..._inCategories].firstWhere((c) => c.id == id, orElse: () => _outCategories.last);

const _currencies = ['Rs', '\$', '€', '£', '₹', 'AED', 'SAR', '৳'];
// The app's own green and red.
const _cashIn = AppColors.success;
const _cashOut = AppColors.danger;

// --- Used by the assistant ---

/// Records spending in the current cash book. Returns the entry id.
Future<String> addExpense(double amount, String category, String note) async {
  final id = DateTime.now().microsecondsSinceEpoch.toString();
  await MoneyStore.save(
    MoneyEntry(id: id, accountId: MoneyStore.current.id, isIn: false, amount: amount, category: _outCategories.any((c) => c.id == category) ? category : 'other', note: note, date: DateTime.now()),
  );
  return id;
}

/// Records money received in the current cash book. Returns the entry id.
Future<String> addIncome(double amount, String note) async {
  final id = DateTime.now().microsecondsSinceEpoch.toString();
  final lower = note.toLowerCase();
  final category = RegExp(r'salary|tankhwa|tankhwah|talab').hasMatch(lower)
      ? 'salary'
      : RegExp(r'gift|eidi|tohfa').hasMatch(lower)
      ? 'gift'
      : 'other_in';
  await MoneyStore.save(MoneyEntry(id: id, accountId: MoneyStore.current.id, isIn: true, amount: amount, category: category, note: note, date: DateTime.now()));
  return id;
}

Future<void> removeExpense(String id) => MoneyStore.delete(id);

/// This month's cash out in the current book, and the currency.
(double, String) spentThisMonth() {
  final now = DateTime.now();
  final total = MoneyStore.entries(MoneyStore.current.id).where((e) => !e.isIn && e.date.year == now.year && e.date.month == now.month).fold(0.0, (a, e) => a + e.amount);
  return (total, MoneyStore.currency);
}

String expenseCategoryLabel(String id) => _cat(id).label;

// --- Screen ---

enum _Period { all, day, week, month, year }

/// Cash books: cash in / cash out with running balance, several accounts,
/// and All / Daily / Weekly / Monthly / Yearly views.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  var _period = _Period.all;
  var _anchor = DateTime.now();
  String _query = '';
  bool _searching = false;

  String _money(double v, {bool sign = false}) {
    final s = NumberFormat('#,##0.##').format(v.abs());
    return '${sign && v < 0 ? '-' : ''}${MoneyStore.currency} $s';
  }

  DateTimeRange? get _range {
    final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
    return switch (_period) {
      _Period.all => null,
      _Period.day => DateTimeRange(start: d, end: d.add(const Duration(days: 1))),
      _Period.week => () {
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return DateTimeRange(start: monday, end: monday.add(const Duration(days: 7)));
      }(),
      _Period.month => DateTimeRange(start: DateTime(d.year, d.month), end: DateTime(d.year, d.month + 1)),
      _Period.year => DateTimeRange(start: DateTime(d.year), end: DateTime(d.year + 1)),
    };
  }

  String get _rangeLabel {
    final r = _range;
    if (r == null) return 'All time';
    return switch (_period) {
      _Period.day => DateFormat('EEE, d MMM yyyy').format(r.start),
      _Period.week => '${DateFormat('d MMM').format(r.start)} – ${DateFormat('d MMM yyyy').format(r.end.subtract(const Duration(days: 1)))}',
      _Period.month => DateFormat('MMMM yyyy').format(r.start),
      _ => '${r.start.year}',
    };
  }

  void _shift(int dir) {
    setState(() {
      _anchor = switch (_period) {
        _Period.day => _anchor.add(Duration(days: dir)),
        _Period.week => _anchor.add(Duration(days: 7 * dir)),
        _Period.month => DateTime(_anchor.year, _anchor.month + dir, 1),
        _Period.year => DateTime(_anchor.year + dir, 1, 1),
        _Period.all => _anchor,
      };
    });
  }

  // --- Entry sheet ---

  Future<void> _edit({required bool isIn, MoneyEntry? existing}) async {
    final amount = TextEditingController(text: existing == null ? '' : NumberFormat('0.##').format(existing.amount));
    final note = TextEditingController(text: existing?.note);
    var incoming = existing?.isIn ?? isIn;
    var category = existing?.category ?? (incoming ? 'other_in' : 'food');
    var date = existing?.date ?? DateTime.now();
    final account = MoneyStore.current;

    final result = await showLiquidSheet<String>(
      context: context,
      title: existing == null ? (incoming ? 'Cash in' : 'Cash out') : 'Edit entry',
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          final cats = incoming ? _inCategories : _outCategories;
          final color = incoming ? _cashIn : _cashOut;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (existing != null)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Cash in')),
                    ButtonSegment(value: false, label: Text('Cash out')),
                  ],
                  selected: {incoming},
                  onSelectionChanged: (v) => setSheet(() {
                    incoming = v.first;
                    category = incoming ? 'other_in' : 'other';
                  }),
                ),
              const SheetLabel('Amount'),
              TextField(
                controller: amount,
                autofocus: existing == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
                decoration: InputDecoration(prefixText: '${MoneyStore.currency} ', hintText: '0'),
              ),
              const SheetLabel('Remark'),
              TextField(
                controller: note,
                decoration: InputDecoration(hintText: incoming ? 'e.g. salary, sold phone' : 'e.g. fruits, bus fare'),
              ),
              const SheetLabel('Category'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in cats)
                    ChoiceChip(
                      avatar: Icon(cat.icon, size: 18, color: category == cat.id ? Colors.white : cat.color),
                      label: Text(cat.label),
                      selected: category == cat.id,
                      onSelected: (_) => setSheet(() => category = cat.id),
                      selectedColor: color,
                      labelStyle: TextStyle(color: category == cat.id ? Colors.white : null, fontWeight: FontWeight.w700),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SheetLabel('Date & time'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(DateFormat('d MMM yyyy').format(date)),
                      onPressed: () async {
                        final d = await showLiquidDatePicker(c, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)), title: 'Entry date');
                        if (d != null) setSheet(() => date = DateTime(d.year, d.month, d.day, date.hour, date.minute));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(DateFormat('h:mm a').format(date)),
                      onPressed: () async {
                        final t = await showLiquidTimePicker(c, initialTime: TimeOfDay.fromDateTime(date), title: 'Entry time');
                        if (t != null) setSheet(() => date = DateTime(date.year, date.month, date.day, t.hour, t.minute));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Book: ${account.name}', style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
              const SizedBox(height: 18),
              GlowButton(label: 'Save', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, 'save')),
              if (existing != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(c, 'delete'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete entry'),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (result == 'delete' && existing != null) {
      await MoneyStore.delete(existing.id);
      if (!mounted) return;
      setState(() {});
      showUndoSnackBar(context, 'Entry deleted', () async {
        await MoneyStore.save(existing);
        if (mounted) setState(() {});
      });
      return;
    }
    if (result != 'save') return;
    final value = double.tryParse(amount.text);
    if (value == null || value <= 0) {
      if (mounted) showInfoSnackBar(context, 'Enter an amount.');
      return;
    }
    await MoneyStore.save(
      MoneyEntry(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        accountId: existing?.accountId ?? account.id,
        isIn: incoming,
        amount: value,
        category: category,
        note: note.text.trim(),
        date: date,
      ),
    );
    if (mounted) setState(() {});
  }

  // --- Accounts ---

  Future<String?> _askName(String title, [String? initial]) {
    final c = TextEditingController(text: initial);
    return showLiquidDialog<String>(
      context: context,
      title: title,
      icon: Icons.menu_book_rounded,
      builder: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Personal, Shop, Home'),
          ),
          const SizedBox(height: 18),
          LiquidDialogActions(confirmLabel: 'Save', onCancel: () => Navigator.pop(d), onConfirm: () => Navigator.pop(d, c.text.trim())),
        ],
      ),
    );
  }

  Future<void> _accounts() async {
    await showLiquidSheet<void>(
      context: context,
      title: 'Cash books',
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) {
          final current = MoneyStore.current;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in MoneyStore.accounts)
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  highlighted: a.id == current.id,
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                  onTap: () async {
                    await MoneyStore.setCurrent(a.id);
                    if (c.mounted) Navigator.pop(c);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: a.id == current.id ? AppColors.accentOn(c) : null),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            Text(
                              'Balance ${_money(MoneyStore.balance(a.id), sign: true)}',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: MoneyStore.balance(a.id) < 0 ? _cashOut : _cashIn),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rename',
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () async {
                          final name = await _askName('Rename book', a.name);
                          if (name == null || name.isEmpty) return;
                          await MoneyStore.renameAccount(a.id, name);
                          setSheet(() {});
                        },
                      ),
                      if (MoneyStore.accounts.length > 1)
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () async {
                            final ok = await showLiquidConfirm(
                              c,
                              title: 'Delete "${a.name}"?',
                              message: 'This deletes the book and all ${MoneyStore.entries(a.id).length} entries in it. This can\'t be undone.',
                              confirmLabel: 'Delete',
                              icon: Icons.delete_forever_rounded,
                              destructive: true,
                            );
                            if (!ok) return;
                            await MoneyStore.deleteAccount(a.id);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              GlowButton(
                label: 'New cash book',
                icon: Icons.add_rounded,
                onPressed: () async {
                  final name = await _askName('New cash book');
                  if (name == null || name.isEmpty) return;
                  await MoneyStore.addAccount(name);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ],
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _settings() async {
    final account = MoneyStore.current;
    final budget = TextEditingController(text: MoneyStore.budget(account.id) > 0 ? MoneyStore.budget(account.id).toStringAsFixed(0) : '');
    var currency = MoneyStore.currency;
    final ok = await showLiquidSheet<bool>(
      context: context,
      title: 'Budget & currency',
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetLabel('Currency'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cur in _currencies)
                  ChoiceChip(
                    label: Text(cur),
                    selected: currency == cur,
                    onSelected: (_) => setSheet(() => currency = cur),
                    selectedColor: AppColors.royal,
                    labelStyle: TextStyle(color: currency == cur ? Colors.white : null, fontWeight: FontWeight.w800),
                    showCheckmark: false,
                  ),
              ],
            ),
            SheetLabel('Monthly spending budget for "${account.name}" (optional)'),
            TextField(
              controller: budget,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'e.g. 50000'),
            ),
            const SizedBox(height: 24),
            GlowButton(label: 'Save', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, true)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await MoneyStore.setCurrency(currency);
    await MoneyStore.setBudget(account.id, double.tryParse(budget.text) ?? 0);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final account = MoneyStore.current;
    final all = MoneyStore.entries(account.id);
    final running = MoneyStore.runningBalances(account.id);
    final r = _range;
    final q = _query.trim().toLowerCase();
    final shown = all.where((e) {
      if (r != null && (e.date.isBefore(r.start) || !e.date.isBefore(r.end))) return false;
      if (q.isNotEmpty && !'${e.note} ${_cat(e.category).label} ${e.amount}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    final totalIn = shown.where((e) => e.isIn).fold(0.0, (a, e) => a + e.amount);
    final totalOut = shown.where((e) => !e.isIn).fold(0.0, (a, e) => a + e.amount);
    final bookBalance = MoneyStore.balance(account.id);
    final budget = MoneyStore.budget(account.id);
    final now = DateTime.now();
    final monthOut = all.where((e) => !e.isIn && e.date.year == now.year && e.date.month == now.month).fold(0.0, (a, e) => a + e.amount);

    final days = <DateTime, List<MoneyEntry>>{};
    for (final e in shown) {
      days.putIfAbsent(DateUtils.dateOnly(e.date), () => []).add(e);
    }

    return Scaffold(
      body: AmbientBackground(
        child: Column(
          children: [
            LiquidHeader(
              title: '',
              titleWidget: Semantics(
                button: true,
                label: 'Cash book ${account.name}. Change book',
                child: InkWell(
                  onTap: _accounts,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 32),
                    ],
                  ),
                ),
              ),
              subtitle: 'Balance ${_money(bookBalance, sign: true)}',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              actions: [
                GlassIconButton(
                  icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                  onTap: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _query = '';
                  }),
                ),
                const SizedBox(width: 8),
                GlassIconButton(icon: Icons.tune_rounded, onTap: _settings),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (_searching)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(hintText: 'Search remarks, categories, amounts', prefixIcon: Icon(Icons.search_rounded)),
                      ),
                    ),
                  // Period switcher in the app's glass style.
                  _PeriodSwitcher(
                    value: _period,
                    onChanged: (p) => setState(() {
                      _period = p;
                      _anchor = DateTime.now();
                    }),
                  ),
                  const SizedBox(height: 10),
                  // Totals for the period.
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (_period != _Period.all) GlassIconButton(icon: Icons.chevron_left_rounded, onLiquid: false, size: 32, onTap: () => _shift(-1)),
                            Expanded(
                              child: Text(
                                _rangeLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (_period != _Period.all) GlassIconButton(icon: Icons.chevron_right_rounded, onLiquid: false, size: 32, onTap: () => _shift(1)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Total(label: 'Cash in', value: _money(totalIn), color: _cashIn),
                            _Total(label: 'Cash out', value: _money(totalOut), color: _cashOut),
                            _Total(label: 'Balance', value: _money(totalIn - totalOut, sign: true), color: totalIn - totalOut < 0 ? _cashOut : textTheme.titleLarge?.color ?? Colors.black),
                          ],
                        ),
                        if (budget > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (monthOut / budget).clamp(0.0, 1.0),
                              minHeight: 8,
                              color: monthOut > budget
                                  ? _cashOut
                                  : monthOut > budget * 0.8
                                  ? AppColors.warning
                                  : _cashIn,
                              backgroundColor: AppColors.royal.withValues(alpha: 0.1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            monthOut > budget ? '${_money(monthOut - budget)} over this month\'s budget' : '${_money(budget - monthOut)} left of ${_money(budget)} this month',
                            style: textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 52, color: AppColors.accentOn(context).withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(q.isNotEmpty ? 'Nothing matches "$_query".' : 'No entries here yet. Add cash in or cash out below.', textAlign: TextAlign.center, style: textTheme.bodyMedium),
                        ],
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Entry', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ),
                          const SizedBox(
                            width: 84,
                            child: Text(
                              'Cash in',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: _cashIn, fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(
                            width: 92,
                            child: Text(
                              'Cash out',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: _cashOut, fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final day in days.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Text(DateFormat('EEE, d MMM yyyy').format(day.key), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                      ),
                      for (final e in day.value)
                        GlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          onTap: () => _edit(isIn: e.isIn, existing: e),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: _cat(e.category).color.withValues(alpha: 0.14)),
                                child: Icon(_cat(e.category).icon, size: 18, color: _cat(e.category).color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.note.isEmpty ? _cat(e.category).label : e.note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(DateFormat('h:mm a').format(e.date), style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat('#,##0.##').format(e.amount),
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: e.isIn ? _cashIn : _cashOut),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Balance ${NumberFormat('#,##0.##').format(running[e.id] ?? 0)}', style: textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
            // Cash in / Cash out, on a frosted bar like the nav bar.
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.55),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: GlowButton(label: 'Cash In', icon: Icons.south_west_rounded, onPressed: () => _edit(isIn: true)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GlassButton(label: 'Cash Out', icon: Icons.north_east_rounded, onTap: () => _edit(isIn: false)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label, value;
  final Color color;

  const _Total({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted glass button with a pink→violet edge (pairs with GlowButton).
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [AppColors.pink, AppColors.violet]),
            boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18.4), color: isDark ? AppColors.darkCardBg : Colors.white),
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFD86AB8), AppColors.violet]).createShader(r),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All / Daily / Weekly / Monthly / Yearly as a glass pill with a sliding
/// gradient highlight.
class _PeriodSwitcher extends StatelessWidget {
  final _Period value;
  final ValueChanged<_Period> onChanged;

  const _PeriodSwitcher({required this.value, required this.onChanged});

  static const _labels = {_Period.all: 'All', _Period.day: 'Daily', _Period.week: 'Weekly', _Period.month: 'Monthly', _Period.year: 'Yearly'};

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    return GlassCard(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / _Period.values.length;
          return SizedBox(
            height: 38,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: w * value.index,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppColors.primaryGradient,
                      boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final p in _Period.values)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: p == value,
                            label: _labels[p],
                            excludeSemantics: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(p),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: p == value ? Colors.white : textColor,
                                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                                  ),
                                  child: Text(_labels[p]!, maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
