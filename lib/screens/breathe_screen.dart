import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';

/// A breathing pattern: seconds for in, hold, out, hold.
class _Pattern {
  final String name, purpose;
  final List<int> steps;

  const _Pattern(this.name, this.purpose, this.steps);
}

const _patterns = [
  _Pattern('Calm', 'Slow down and relax (4-7-8)', [4, 7, 8, 0]),
  _Pattern('Box', 'Focus and steady nerves (4-4-4-4)', [4, 4, 4, 4]),
  _Pattern('Easy', 'Gentle breathing anytime (4-6)', [4, 0, 6, 0]),
];

const _phaseNames = ['Breathe in', 'Hold', 'Breathe out', 'Hold'];

/// Guided breathing with an expanding circle.
class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});

  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen> with SingleTickerProviderStateMixin {
  var _pattern = _patterns.first;
  var _minutes = 2;
  bool _running = false;
  int _phase = 0;
  int _left = 0; // seconds in this phase
  int _elapsed = 0;
  Timer? _timer;
  late final AnimationController _circle = AnimationController(vsync: this, lowerBound: 0, upperBound: 1, value: 0);

  @override
  void dispose() {
    _timer?.cancel();
    _circle.dispose();
    super.dispose();
  }

  void _startPhase(int phase) {
    var p = phase % 4;
    while (_pattern.steps[p] == 0) {
      p = (p + 1) % 4;
    }
    _phase = p;
    _left = _pattern.steps[p];
    HapticFeedback.lightImpact();
    final d = Duration(seconds: _left);
    if (p == 0) _circle.animateTo(1, duration: d, curve: Curves.easeInOut);
    if (p == 2) _circle.animateTo(0, duration: d, curve: Curves.easeInOut);
  }

  void _start() {
    setState(() {
      _running = true;
      _elapsed = 0;
      _circle.value = 0;
      _startPhase(0);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _elapsed++;
      _left--;
      if (_left <= 0 && _elapsed >= _minutes * 60 && _phase >= 2) {
        _finish();
        return;
      }
      setState(() {
        if (_left <= 0) _startPhase(_phase + 1);
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _circle.animateTo(0, duration: const Duration(milliseconds: 600));
    setState(() => _running = false);
  }

  Future<void> _finish() async {
    _stop();
    final box = Hive.box(HiveService.settingsBox);
    final key = '${HiveService.getCurrentUser()}_mindfulLog';
    final log = Map<String, dynamic>.from((box.get(key) as Map?) ?? const {});
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    log[today] = ((log[today] ?? 0) as int) + _minutes;
    await box.put(key, log);
    await HiveService.addXp(10);
    if (mounted) showInfoSnackBar(context, 'Nicely done. $_minutes mindful minutes · +10 XP 🌿', icon: Icons.spa_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final today = ((Hive.box(HiveService.settingsBox).get('${HiveService.getCurrentUser()}_mindfulLog') as Map?) ?? const {})[DateFormat('yyyy-MM-dd').format(DateTime.now())] ?? 0;
    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Breathe',
              subtitle: 'A few slow breaths calm body and mind',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: AnimatedBuilder(
                            animation: _circle,
                            builder: (context, _) {
                              final size = 110 + 140 * _circle.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.sky.withValues(alpha: 0.08)),
                                  ),
                                  Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(colors: [Color(0xFFB9E3FF), AppColors.sky, AppColors.violet]),
                                      boxShadow: [BoxShadow(color: AppColors.sky.withValues(alpha: 0.45), blurRadius: 30 * (0.5 + _circle.value))],
                                    ),
                                  ),
                                  Semantics(
                                    liveRegion: true,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_running ? _phaseNames[_phase] : 'Ready', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                        if (_running) Text('$_left', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _running ? '${((_minutes * 60 - _elapsed).clamp(0, 9999) ~/ 60)}:${((_minutes * 60 - _elapsed).clamp(0, 9999) % 60).toString().padLeft(2, '0')} left' : 'Today: $today mindful minutes',
                          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_running) ...[
                    for (final p in _patterns)
                      GlassCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        highlighted: p == _pattern,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        onTap: () => setState(() => _pattern = p),
                        child: Row(
                          children: [
                            Icon(Icons.air_rounded, color: AppColors.accentOn(context)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(p.purpose, style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                                ],
                              ),
                            ),
                            if (p == _pattern) Icon(Icons.check_circle_rounded, color: AppColors.accentOn(context)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      alignment: WrapAlignment.center,
                      children: [1, 2, 5, 10].map((m) {
                        return ChoiceChip(
                          label: Text('$m min'),
                          selected: _minutes == m,
                          onSelected: (_) => setState(() => _minutes = m),
                          selectedColor: AppColors.royal,
                          labelStyle: TextStyle(color: _minutes == m ? Colors.white : null, fontWeight: FontWeight.w700),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    GlowButton(label: 'Start breathing', icon: Icons.play_arrow_rounded, onPressed: _start),
                  ] else
                    OutlinedButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
