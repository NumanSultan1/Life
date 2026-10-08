import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/activity_provider.dart';
import '../providers/vitals_provider.dart';
import 'watch_sync_card.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';
import 'medical_id_screen.dart';
import 'medicines_screen.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 7) return '${d.inDays} days ago';
  return DateFormat('d MMM').format(t);
}

Color statusColor(VitalStatus? s) => switch (s) {
      VitalStatus.good => AppColors.success,
      VitalStatus.watch => AppColors.warning,
      VitalStatus.alert => AppColors.danger,
      null => AppColors.textSecondary,
    };

String statusLabel(VitalStatus? s) => switch (s) {
      VitalStatus.good => 'Normal',
      VitalStatus.watch => 'Keep an eye',
      VitalStatus.alert => 'Check with a doctor',
      null => '',
    };

/// Vitals, body measurements, today's energy and workouts for the
/// Health screen.
class HealthSections extends StatefulWidget {
  const HealthSections({super.key});

  @override
  State<HealthSections> createState() => _HealthSectionsState();
}

class _HealthSectionsState extends State<HealthSections> with WidgetsBindingObserver {
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Keep watch data fresh while this screen is open.
    _auto = Timer.periodic(const Duration(minutes: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _auto?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Samsung Health etc.: pick up the new data.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    Provider.of<VitalsProvider>(context, listen: false).refresh();
    Provider.of<ActivityProvider>(context, listen: false).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final v = Provider.of<VitalsProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final water = Hive.box(HiveService.settingsBox).get('${HiveService.getCurrentUser()}_waterIntake', defaultValue: 0);
    final glasses = water is int ? water : 0;
    final heartMetric = vitalMetrics.firstWhere((m) => m.id == 'heart_rate');
    final vitals = vitalMetrics.where((m) => !['weight', 'height', 'body_fat'].contains(m.id)).toList();
    final bmi = v.bmi;

    Widget title(String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
          child: Row(
            children: [
              Expanded(child: Text(text, style: textTheme.titleMedium?.copyWith(fontSize: 18))),
              ?trailing,
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        const WatchSyncCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _LinkCard(icon: Icons.emergency_rounded, color: AppColors.danger, label: 'Medical ID', note: 'Blood group, allergies, contacts', screen: const MedicalIdScreen()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LinkCard(icon: Icons.medication_rounded, color: AppColors.royal, label: 'Medicines', note: 'Dose reminders', screen: const MedicinesScreen()),
            ),
          ],
        ),

        // Today
        title('Today', trailing: v.loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null),
        GlassCard(
          child: Column(
            children: [
              _TodayRow(
                icon: Icons.favorite_rounded,
                color: AppColors.danger,
                label: 'Heart rate today',
                value: v.heartAvg == null ? '—' : '${v.heartAvg} bpm avg',
                note: v.heartAvg == null ? 'Needs a watch or band, or add a reading' : 'Range ${v.heartMin}–${v.heartMax} bpm',
                onTap: () => showVitalSheet(context, heartMetric),
              ),
              _TodayRow(
                icon: Icons.local_drink_rounded,
                color: AppColors.sky,
                label: 'Water',
                value: v.waterLitres > 0 ? '${v.waterLitres.toStringAsFixed(1)} L' : '$glasses glasses',
                note: v.waterLitres > 0 ? 'From Health Connect' : 'From your water tracker on Home',
              ),
              _TodayRow(
                icon: Icons.bolt_rounded,
                color: AppColors.warning,
                label: 'Total energy burned',
                value: v.totalCalories > 0 ? '${NumberFormat.decimalPattern().format(v.totalCalories)} kcal' : '—',
                note: 'Resting + active calories',
              ),
              _TodayRow(
                icon: Icons.restaurant_rounded,
                color: AppColors.success,
                label: 'Food eaten',
                value: v.caloriesEaten > 0 ? '${NumberFormat.decimalPattern().format(v.caloriesEaten)} kcal' : '—',
                note: 'Logged in a food app that syncs to Health Connect',
                last: true,
              ),
            ],
          ),
        ),

        // Vitals
        title('Vitals'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [for (final m in vitals) _VitalTile(metric: m)],
        ),

        // Body
        title('Body'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            for (final m in vitalMetrics.where((m) => ['weight', 'height', 'body_fat'].contains(m.id))) _VitalTile(metric: m),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.speed_rounded, color: AppColors.success, size: 20), SizedBox(width: 6), Text('BMI', style: TextStyle(fontWeight: FontWeight.w800))]),
                  const Spacer(),
                  Text(bmi == null ? '—' : bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  Text(
                    bmi == null ? 'Add weight and height' : VitalsProvider.bmiLabel(bmi),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: bmi == null ? textTheme.bodyMedium?.color : (bmi >= 18.5 && bmi < 25 ? AppColors.success : AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Workouts
        title('Workouts this week'),
        GlassCard(
          child: v.workouts.isEmpty
              ? Row(
                  children: [
                    const Icon(Icons.fitness_center_rounded, color: AppColors.violet),
                    const SizedBox(width: 12),
                    Expanded(child: Text('No workouts recorded. Workouts from Samsung Health or a watch show up here.', style: textTheme.bodyMedium?.copyWith(height: 1.35))),
                  ],
                )
              : Column(
                  children: [
                    for (final w in v.workouts.take(6))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.violet.withValues(alpha: 0.14)),
                              child: const Icon(Icons.fitness_center_rounded, color: AppColors.violet, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w.type, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(DateFormat('EEE d MMM, h:mm a').format(w.start), style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                                ],
                              ),
                            ),
                            Text('${w.duration.inMinutes} min${w.calories == null ? '' : ' · ${w.calories} kcal'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Text(
          'Ranges are general guidance for adults, not medical advice. If something looks wrong or you feel unwell, talk to a doctor.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(fontSize: 11.5, height: 1.4),
        ),
        if (v.lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Updated ${_ago(v.lastUpdated!)} · pull down to refresh', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontSize: 11)),
          ),
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, note;
  final Widget screen;

  const _LinkCard({required this.icon, required this.color, required this.label, required this.note, required this.screen});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value, note;
  final VoidCallback? onTap;
  final bool last;

  const _TodayRow({required this.icon, required this.color, required this.label, required this.value, required this.note, this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.only(top: 6, bottom: last ? 2 : 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(note, style: textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final VitalMetric metric;

  const _VitalTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final v = Provider.of<VitalsProvider>(context);
    final r = v.latest(metric.id);
    final status = r == null ? null : metric.status?.call(r);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${metric.label}: ${r == null ? 'no reading' : '${metric.format(r)} ${metric.unit}, ${statusLabel(status)}'}',
      excludeSemantics: true,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: () => showVitalSheet(context, metric),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(metric.icon, color: metric.color, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              ],
            ),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: r == null ? '—' : metric.format(r), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  if (r != null) TextSpan(text: ' ${metric.unit}', style: textTheme.bodyMedium?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                if (status != null) ...[
                  Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(status))),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    r == null ? (metric.manualEntry ? 'Tap to add' : 'No data yet') : '${status == null ? '' : '${statusLabel(status)} · '}${_ago(r.time)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status == null ? textTheme.bodyMedium?.color : statusColor(status)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// History of one metric, with "Add reading" for manual entry.
Future<void> showVitalSheet(BuildContext context, VitalMetric metric) {
  return showLiquidSheet(
    context: context,
    title: metric.label,
    builder: (c) => Consumer<VitalsProvider>(
      builder: (c, v, _) {
        final history = v.history(metric.id);
        final textTheme = Theme.of(c).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (metric.range.isNotEmpty)
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(metric.icon, color: metric.color),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Typical: ${metric.range}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (metric.manualEntry) GlowButton(label: 'Add a reading', icon: Icons.add_rounded, onPressed: () => _addReading(c, metric)),
            const SizedBox(height: 10),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No readings yet. ${metric.manualEntry ? 'Add one by hand, or ' : ''}connect Health Connect to bring them in from your watch, scale or Samsung Health.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              )
            else
              for (final r in history.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(metric.status?.call(r)))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${metric.format(r)} ${metric.unit}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('${DateFormat('EEE d MMM, h:mm a').format(r.time)} · ${r.manual ? 'added by you' : 'Health Connect'}', style: textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      if (r.manual)
                        IconButton(
                          tooltip: 'Delete reading',
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () => v.deleteManual(metric.id, r),
                        ),
                    ],
                  ),
                ),
          ],
        );
      },
    ),
  );
}

Future<void> _addReading(BuildContext context, VitalMetric metric) async {
  final first = TextEditingController(), second = TextEditingController();
  final isBp = metric.id == 'blood_pressure';
  final formatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
  final ok = await showLiquidDialog<bool>(
    context: context,
    title: 'Add ${metric.label.toLowerCase()}',
    icon: metric.icon,
    builder: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: first,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [formatter],
                decoration: InputDecoration(hintText: isBp ? 'Top' : 'Value', helperText: isBp ? 'e.g. 120' : null, suffixText: isBp ? null : metric.unit),
              ),
            ),
            if (isBp) ...[
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              Expanded(
                child: TextField(
                  controller: second,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [formatter],
                  decoration: const InputDecoration(hintText: 'Bottom', helperText: 'e.g. 80'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        LiquidDialogActions(confirmLabel: 'Save', onCancel: () => Navigator.pop(c, false), onConfirm: () => Navigator.pop(c, true)),
      ],
    ),
  );
  final value = double.tryParse(first.text);
  final value2 = double.tryParse(second.text);
  first.dispose();
  second.dispose();
  if (ok != true || !context.mounted) return;
  if (value == null || value <= 0 || (isBp && (value2 == null || value2 <= 0))) {
    showInfoSnackBar(context, 'Please enter a number.');
    return;
  }
  await Provider.of<VitalsProvider>(context, listen: false).addManual(metric.id, value, value2: isBp ? value2 : null);
}
