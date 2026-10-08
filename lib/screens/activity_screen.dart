import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/activity_provider.dart';
import '../providers/vitals_provider.dart';
import 'health_sections.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/boot_icon.dart';
import '../widgets/liquid/liquid.dart';

final _number = NumberFormat.decimalPattern();

/// Asks for step permissions with a friendly explanation first.
Future<void> connectActivity(BuildContext context) async {
  final provider = Provider.of<ActivityProvider>(context, listen: false);
  if (!provider.supported) {
    showInfoSnackBar(context, 'Step counting works on the phone app.');
    return;
  }
  final ok = await provider.connect();
  if (!context.mounted) return;
  if (!ok) {
    showInfoSnackBar(context, 'Permission was denied. You can allow "Physical activity" for Life in your phone settings.');
  } else if (!provider.healthConnected) {
    showInfoSnackBar(context, 'Counting live steps. Connect Health Connect for all-day steps and floors.');
  }
}

void _openActivity(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));

/// Live step counter with a boot icon, for the Home header.
class StepsPill extends StatelessWidget {
  const StepsPill({super.key});

  @override
  Widget build(BuildContext context) {
    final a = Provider.of<ActivityProvider>(context);
    if (!a.supported) return const SizedBox.shrink();
    final color = AppColors.accentOn(context);
    return Semantics(
      button: true,
      label: a.isTracking ? '${a.steps} steps today. Open activity' : 'Turn on step counting',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => a.isTracking ? _openActivity(context) : connectActivity(context),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BootIcon(size: 20, color: color),
              const SizedBox(width: 6),
              if (a.isTracking)
                CountUpText(
                  value: a.steps,
                  duration: const Duration(milliseconds: 600),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color),
                )
              else
                Text(
                  'Steps',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live steps, calories and distance for the top of Home.
class LiveMoveCard extends StatelessWidget {
  const LiveMoveCard({super.key});

  @override
  Widget build(BuildContext context) {
    final a = Provider.of<ActivityProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final accent = AppColors.accentOn(context);
    if (!a.isTracking) {
      return GlassCard(
        onTap: () async {
          await connectActivity(context);
          if (context.mounted && a.isTracking) _openActivity(context);
        },
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            BootIcon(size: 28, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Count your steps', style: textTheme.titleMedium?.copyWith(fontSize: 16)),
                  Text(a.supported ? 'Tap to see live steps, calories and km' : 'Step counting works on the phone app', style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
    }
    final progress = a.goal == 0 ? 0.0 : (a.steps / a.goal).clamp(0.0, 1.0);
    Widget stat(Widget icon, Widget value, String label) => Expanded(
      child: Row(
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  child: value,
                ),
                Text(label, style: textTheme.bodyMedium?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
    return GlassCard(
      onTap: () => _openActivity(context),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              stat(BootIcon(size: 24, color: accent), CountUpText(value: a.steps, duration: const Duration(milliseconds: 600)), 'of ${_number.format(a.goal)} steps'),
              stat(const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 24), CountUpText(value: a.liveCalories, duration: const Duration(milliseconds: 600)), 'kcal burned'),
              stat(const Icon(Icons.route_rounded, color: AppColors.sky, size: 24), Text(a.liveDistanceKm.toStringAsFixed(2)), 'km covered'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: accent, backgroundColor: accent.withValues(alpha: 0.14)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('Live', style: textTheme.bodyMedium?.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(a.steps >= a.goal ? 'Goal reached! 🎉' : '${_number.format(a.goal - a.steps)} steps to go', style: textTheme.bodyMedium?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  Future<void> _editGoal(BuildContext context) async {
    final a = Provider.of<ActivityProvider>(context, listen: false);
    double v = (a.goal - 2000) / 18000;
    int goalFor(double x) => (2000 + (x * 18000) / 500).round() * 500;
    await showLiquidSheet(
      context: context,
      title: 'Daily step goal',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setStateModal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetLabel('How many steps a day?'),
            BubbleSlider(value: v.clamp(0.0, 1.0), labelBuilder: (x) => _number.format(goalFor(x)), onChanged: (x) => setStateModal(() => v = x)),
            const SizedBox(height: 8),
            Text('Most people aim for 8,000–10,000 steps. Arcs use 10,000.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            GlowButton(
              label: 'Save goal',
              onPressed: () {
                a.setGoal(goalFor(v));
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = Provider.of<ActivityProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final week = a.thisWeek();
    final weekMax = math.max(a.goal, week.whereType<int>().fold(0, math.max));
    final todayIndex = DateTime.now().weekday - 1;

    return Scaffold(
      body: AmbientBackground(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([a.refresh(), Provider.of<VitalsProvider>(context, listen: false).refresh()]),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              LiquidHeader(
                title: 'Health',
                subtitle: 'Steps, heart, vitals, body and sleep in one place',
                leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StaggerIn(
                      child: GlassCard(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 210,
                              height: 210,
                              child: _StepsRing(steps: a.steps, goal: a.goal, stroke: 16, color: AppColors.royal),
                            ),
                            const SizedBox(height: 12),
                            if (a.sensorAllowed) const _LiveDot(dark: true),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _editGoal(context),
                              icon: Icon(Icons.flag_rounded, color: AppColors.accentOn(context)),
                              label: Text(
                                'Goal: ${_number.format(a.goal)} steps · change',
                                style: TextStyle(color: AppColors.accentOn(context), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _Stat(icon: Icons.stairs_rounded, color: AppColors.violet, value: '${a.floors}', label: 'Floors', note: a.healthConnected ? null : 'Needs Health Connect'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Stat(icon: Icons.route_rounded, color: AppColors.sky, value: a.liveDistanceKm.toStringAsFixed(2), label: 'Kilometres'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Stat(icon: Icons.local_fire_department_rounded, color: AppColors.warning, value: '${a.liveCalories}', label: 'Active kcal'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.navy.withValues(alpha: 0.12)),
                            child: Icon(Icons.bedtime_rounded, color: AppColors.accentOn(context)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.sleepLastNight == null ? 'Sleep' : '${a.sleepLastNight!.inHours} h ${a.sleepLastNight!.inMinutes % 60} min of sleep',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                Text(
                                  a.sleepLastNight == null
                                      ? (a.healthConnected
                                            ? 'No sleep recorded last night. A sleep tracker or watch that syncs to Health Connect fills this in.'
                                            : 'Connect Health Connect to see last night\'s sleep.')
                                      : a.sleepLastNight!.inMinutes >= 420
                                      ? 'Last night · well rested 😴'
                                      : 'Last night · aim for 7+ hours. Set a bedtime reminder in Profile.',
                                  style: textTheme.bodyMedium?.copyWith(fontSize: 12.5, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const HealthSections(),
                    const SizedBox(height: 22),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('This week', style: textTheme.titleMedium?.copyWith(fontSize: 16)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 120,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(7, (i) {
                                final v = week[i] ?? 0;
                                final reached = v >= a.goal;
                                return Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (v > 0) Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v', style: textTheme.bodyMedium?.copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: weekMax == 0 ? 0 : v / weekMax),
                                        duration: Duration(milliseconds: 700 + i * 80),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, h, _) => Container(
                                          width: 20,
                                          height: 4 + 76 * h,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: reached ? const [AppColors.success, Color(0xFF1E9E87)] : const [AppColors.sky, AppColors.royal],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                                        style: TextStyle(
                                          fontWeight: i == todayIndex ? FontWeight.w900 : FontWeight.w600,
                                          color: i == todayIndex ? AppColors.accentOn(context) : textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Green bars reached your goal.', style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SourcesCard(provider: a),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  final ActivityProvider provider;

  const _SourcesCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final a = provider;
    final textTheme = Theme.of(context).textTheme;
    Widget row(IconData icon, String title, String text, bool on, {String? action, VoidCallback? onAction}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: on ? AppColors.success : textTheme.bodyMedium?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(text, style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action,
                style: TextStyle(color: AppColors.accentOn(context), fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data sources', style: textTheme.titleMedium?.copyWith(fontSize: 16)),
          row(
            Icons.sensors_rounded,
            'Phone step sensor',
            a.sensorAllowed ? 'On: live steps while Life is open' : 'Off: allow "Physical activity"',
            a.sensorAllowed,
            action: a.sensorAllowed ? null : 'Turn on',
            onAction: () => connectActivity(context),
          ),
          row(
            Icons.favorite_rounded,
            'Health Connect',
            a.healthConnected
                ? 'Connected: all-day steps, floors, distance, calories'
                : a.healthAvailable
                ? 'Adds all-day steps and floors (Samsung Health can sync to it)'
                : 'Not installed on this phone',
            a.healthConnected,
            action: a.healthConnected ? null : (a.healthAvailable ? 'Connect' : 'Install'),
            onAction: () => a.healthAvailable ? connectActivity(context) : a.installHealthConnect(),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value, label;
  final String? note;

  const _Stat({required this.icon, required this.color, required this.value, required this.label, this.note});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
          if (note != null) Text(note!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" indicator.
class _LiveDot extends StatefulWidget {
  final bool dark;

  const _LiveDot({this.dark = false});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.dark ? AppColors.success : Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'LIVE',
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

/// Ring that fills toward the step goal, with the count in the middle.
class _StepsRing extends StatelessWidget {
  final int steps, goal;
  final double stroke;
  final Color color;

  const _StepsRing({required this.steps, required this.goal, required this.stroke, required this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: goal == 0 ? 0 : (steps / goal).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) =>
              CircularProgressIndicator(value: v, strokeWidth: stroke, strokeCap: StrokeCap.round, color: steps >= goal ? AppColors.success : color, backgroundColor: color.withValues(alpha: 0.18)),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BootIcon(color: textColor, size: 30),
              Text(
                _number.format(steps),
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: textColor, height: 1.1),
              ),
              Text('steps today', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
