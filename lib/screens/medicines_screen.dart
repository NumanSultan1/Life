import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';

/// A medicine with daily dose times.
class Medicine {
  final String id, name, dose, note;
  final List<String> times; // HH:mm

  const Medicine({required this.id, required this.name, this.dose = '', this.note = '', this.times = const []});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'dose': dose, 'note': note, 'times': times};
  static Medicine fromMap(Map m) => Medicine(
        id: m['id'] as String,
        name: m['name'] as String,
        dose: (m['dose'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        times: List<String>.from((m['times'] as List?) ?? const []),
      );
}

/// Medicines, their reminders, and which doses were taken each day.
class MedicineStore {
  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _user => HiveService.getCurrentUser();
  static String _day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static List<Medicine> get all => ((_box.get('${_user}_medicines') as List?) ?? const []).map((m) => Medicine.fromMap(m as Map)).toList();

  static Future<void> _saveAll(List<Medicine> list) => _box.put('${_user}_medicines', list.map((m) => m.toMap()).toList());

  static Future<void> save(Medicine med) async {
    final list = all;
    final old = list.where((m) => m.id == med.id).firstOrNull;
    if (old != null) await _cancel(old);
    final i = list.indexWhere((m) => m.id == med.id);
    i == -1 ? list.add(med) : list[i] = med;
    await _saveAll(list);
    await _schedule(med);
  }

  static Future<void> delete(Medicine med) async {
    await _cancel(med);
    await _saveAll(all..removeWhere((m) => m.id == med.id));
  }

  static Set<String> takenOn(DateTime d) => Set<String>.from(((_box.get('${_user}_medsTaken') as Map?) ?? const {})[_day(d)] as List? ?? const []);

  static Future<void> toggleTaken(Medicine med, String time) async {
    final log = Map<String, dynamic>.from((_box.get('${_user}_medsTaken') as Map?) ?? const {});
    final today = _day(DateTime.now());
    final set = Set<String>.from((log[today] as List?) ?? const []);
    final key = '${med.id}@$time';
    set.contains(key) ? set.remove(key) : set.add(key);
    log[today] = set.toList();
    // Keep about two months of history.
    final keys = log.keys.toList()..sort();
    for (final k in keys.take(keys.length > 60 ? keys.length - 60 : 0)) {
      log.remove(k);
    }
    await _box.put('${_user}_medsTaken', log);
  }

  /// Doses taken / planned today.
  static (int, int) today() {
    final meds = all;
    final taken = takenOn(DateTime.now());
    final total = meds.fold(0, (n, m) => n + m.times.length);
    final done = meds.fold(0, (n, m) => n + m.times.where((t) => taken.contains('${m.id}@$t')).length);
    return (done, total);
  }

  static Future<void> _schedule(Medicine med) async {
    for (final t in med.times) {
      final time = parseTimeOfDay(t);
      if (time == null) continue;
      await NotificationService.scheduleDaily(
        id: NotificationService.medicineId('${med.id}@$t'),
        title: '💊 Time for ${med.name}',
        body: med.dose.isEmpty ? 'Tap to open Life and mark it taken.' : '${med.dose}${med.note.isEmpty ? '' : ' · ${med.note}'}',
        time: time,
      );
    }
  }

  static Future<void> _cancel(Medicine med) async {
    for (final t in med.times) {
      await NotificationService.cancel(NotificationService.medicineId('${med.id}@$t'));
    }
  }

  /// Re-arms all medicine reminders (after login or restore).
  static Future<void> resync() async {
    for (final m in all) {
      await _schedule(m);
    }
  }
}

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  Future<void> _edit([Medicine? existing]) async {
    final name = TextEditingController(text: existing?.name);
    final dose = TextEditingController(text: existing?.dose);
    final note = TextEditingController(text: existing?.note);
    final times = <TimeOfDay>[...?existing?.times.map(parseTimeOfDay).whereType<TimeOfDay>()];
    if (times.isEmpty) times.add(const TimeOfDay(hour: 9, minute: 0));

    final saved = await showLiquidSheet<bool>(
      context: context,
      title: existing == null ? 'Add a medicine' : 'Edit medicine',
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetLabel('Name'),
            TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(hintText: 'e.g. Vitamin D, Panadol')),
            const SheetLabel('Dose (optional)'),
            TextField(controller: dose, decoration: const InputDecoration(hintText: 'e.g. 1 tablet, 5 ml')),
            const SheetLabel('Note (optional)'),
            TextField(controller: note, decoration: const InputDecoration(hintText: 'e.g. after food')),
            const SheetLabel('Remind me at'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < times.length; i++)
                  InputChip(
                    label: Text(times[i].format(c), style: const TextStyle(fontWeight: FontWeight.w800)),
                    avatar: const Icon(Icons.alarm_rounded, size: 18),
                    onPressed: () async {
                      final t = await showLiquidTimePicker(c, initialTime: times[i], title: 'Dose time');
                      if (t != null) setSheet(() => times[i] = t);
                    },
                    onDeleted: times.length > 1 ? () => setSheet(() => times.removeAt(i)) : null,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add time'),
                  onPressed: () async {
                    final t = await showLiquidTimePicker(c, initialTime: const TimeOfDay(hour: 21, minute: 0), title: 'Dose time');
                    if (t != null) setSheet(() => times.add(t));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: existing == null ? 'Add medicine' : 'Save changes',
              icon: Icons.check_rounded,
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  showInfoSnackBar(c, 'Give the medicine a name.');
                  return;
                }
                Navigator.pop(c, true);
              },
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (!await NotificationService.requestPermission() && mounted) {
      showInfoSnackBar(context, 'Notifications are off, so reminders won\'t ring. Turn them on in phone settings.');
    }
    times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    await MedicineStore.save(Medicine(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.text.trim(),
      dose: dose.text.trim(),
      note: note.text.trim(),
      times: times.map(formatTimeOfDay).toList(),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final meds = MedicineStore.all;
    final taken = MedicineStore.takenOn(DateTime.now());
    final (done, total) = MedicineStore.today();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Medicines',
              subtitle: total == 0 ? 'Never miss a dose' : '$done of $total doses taken today',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (meds.isEmpty)
                    GlassCard(
                      child: Column(
                        children: [
                          const Icon(Icons.medication_rounded, size: 56, color: AppColors.royal),
                          const SizedBox(height: 10),
                          Text('No medicines yet', style: textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('Add your medicines or vitamins and Life will remind you at each dose time.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(height: 1.4)),
                        ],
                      ),
                    ),
                  for (final m in meds)
                    GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      onTap: () => _edit(m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.royal.withValues(alpha: 0.12)),
                                child: const Icon(Icons.medication_rounded, color: AppColors.royal),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    if (m.dose.isNotEmpty || m.note.isNotEmpty)
                                      Text([m.dose, m.note].where((s) => s.isNotEmpty).join(' · '), style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete ${m.name}',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  await MedicineStore.delete(m);
                                  setState(() {});
                                  if (context.mounted) {
                                    showUndoSnackBar(context, '${m.name} removed', () async {
                                      await MedicineStore.save(m);
                                      if (mounted) setState(() {});
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in m.times)
                                Builder(builder: (_) {
                                  final isTaken = taken.contains('${m.id}@$t');
                                  final time = parseTimeOfDay(t)!;
                                  return Semantics(
                                    button: true,
                                    checked: isTaken,
                                    label: '${m.name} at ${time.format(context)}, ${isTaken ? 'taken' : 'not taken'}',
                                    excludeSemantics: true,
                                    child: Pressable(
                                      onTap: () async {
                                        await MedicineStore.toggleTaken(m, t);
                                        setState(() {});
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 220),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: isTaken ? const LinearGradient(colors: [AppColors.success, Color(0xFF1E9E87)]) : null,
                                          color: isTaken ? null : AppColors.royal.withValues(alpha: 0.08),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(isTaken ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: isTaken ? Colors.white : AppColors.accentOn(context)),
                                            const SizedBox(width: 6),
                                            Text(time.format(context), style: TextStyle(fontWeight: FontWeight.w800, color: isTaken ? Colors.white : null)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  GlowButton(label: 'Add a medicine', icon: Icons.add_rounded, onPressed: () => _edit()),
                  const SizedBox(height: 12),
                  Text('Tap a time to mark that dose as taken. Always follow your doctor\'s instructions.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
