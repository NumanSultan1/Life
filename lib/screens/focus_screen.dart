import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../services/focus_store.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';
import 'app_limits_screen.dart';

/// Pomodoro-style focus timer. The end time is saved, so the countdown
/// keeps going if you leave the app; with "block apps" on, the apps from
/// App time limits are blocked until the session ends (Android).
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  static const _endKey = 'focusEndsAt';
  static const _lengthKey = 'focusLength';
  static const _taskKey = 'focusTask';
  static const _sessionDoneId = 5;

  Box get _box => Hive.box(HiveService.settingsBox);
  String get _user => HiveService.getCurrentUser();

  int _minutes = 25;
  bool _blockApps = true;
  String? _taskTitle;
  DateTime? _endsAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final saved = DateTime.tryParse(_box.get('${_user}_$_endKey', defaultValue: '') as String);
    _minutes = _box.get('${_user}_$_lengthKey', defaultValue: 25) as int;
    _taskTitle = _box.get('${_user}_$_taskKey') as String?;
    if (saved != null) {
      _endsAt = saved;
      _startTicker();
      _checkFinished();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkFinished();
  }

  Duration get _left => _endsAt == null ? Duration(minutes: _minutes) : _endsAt!.difference(DateTime.now());

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkFinished();
    });
  }

  Future<void> _start() async {
    final ends = DateTime.now().add(Duration(minutes: _minutes));
    await _box.put('${_user}_$_endKey', ends.toIso8601String());
    await _box.put('${_user}_$_lengthKey', _minutes);
    if (_taskTitle != null) await _box.put('${_user}_$_taskKey', _taskTitle);
    setState(() => _endsAt = ends);
    _startTicker();
    await NotificationService.scheduleOnce(
      id: _sessionDoneId,
      title: '🎯 Focus session complete',
      body: 'Great work${_taskTitle == null ? '' : ' on "$_taskTitle"'}! Take a 5-minute break.',
      when: ends,
    );
    if (_blockApps && AppLimitsChannel.supported) {
      try {
        await AppLimitsChannel.setFocusUntil(ends);
      } catch (_) {}
    }
  }

  Future<void> _stop({bool completed = false}) async {
    _ticker?.cancel();
    await _box.delete('${_user}_$_endKey');
    await _box.delete('${_user}_$_taskKey');
    await NotificationService.cancel(_sessionDoneId);
    if (AppLimitsChannel.supported) {
      try {
        await AppLimitsChannel.setFocusUntil(DateTime.fromMillisecondsSinceEpoch(0));
      } catch (_) {}
    }
    if (completed) {
      await FocusStore.addSession(_minutes);
      await HiveService.addXp(15);
    }
    if (!mounted) return;
    setState(() {
      _endsAt = null;
      _taskTitle = null;
    });
    if (completed) showInfoSnackBar(context, 'Session complete! +15 XP 🎯 Take a short break.');
  }

  void _checkFinished() {
    if (_endsAt != null && !DateTime.now().isBefore(_endsAt!)) _stop(completed: true);
  }

  Future<void> _pickTask() async {
    final open = Provider.of<TaskProvider>(context, listen: false).todayTasks.where((t) => !t.isDoneOn(DateTime.now())).toList();
    final picked = await showLiquidSheet<String>(
      context: context,
      title: 'Focus on…',
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (open.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No open tasks today. You can still focus without one.')),
          for (final t in open)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.radio_button_unchecked_rounded),
              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(c, t.title),
            ),
          TextButton(onPressed: () => Navigator.pop(c, ''), child: const Text('No task')),
        ],
      ),
    );
    if (picked != null) setState(() => _taskTitle = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final running = _endsAt != null;
    final left = _left.isNegative ? Duration.zero : _left;
    final total = Duration(minutes: _minutes).inSeconds;
    final progress = running ? 1 - left.inSeconds / total : 0.0;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final textTheme = Theme.of(context).textTheme;
    final todayMinutes = FocusStore.minutesBetween(DateTime.now(), DateTime.now());

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Focus',
              subtitle: running ? 'Stay with it. Your phone can wait.' : 'One task, no distractions',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 230,
                          height: 230,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 14,
                                strokeCap: StrokeCap.round,
                                color: AppColors.royal,
                                backgroundColor: AppColors.lavender.withValues(alpha: 0.25),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Semantics(
                                      liveRegion: true,
                                      label: '$mm minutes $ss seconds left',
                                      child: Text('$mm:$ss', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900)),
                                    ),
                                    Text(running ? 'remaining' : 'ready', style: textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_taskTitle != null)
                          GlassPill(text: 'Focusing on: $_taskTitle', icon: Icons.task_alt_rounded, color: AppColors.royal),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!running) ...[
                    Text('Length', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [15, 25, 45, 60].map((m) {
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
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.task_alt_rounded, color: AppColors.accentOn(context)),
                      title: Text(_taskTitle ?? 'Pick a task (optional)', style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _pickTask,
                    ),
                    if (AppLimitsChannel.supported)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _blockApps,
                        onChanged: (v) => setState(() => _blockApps = v),
                        secondary: Icon(Icons.block_rounded, color: AppColors.accentOn(context)),
                        title: const Text('Block distracting apps', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Blocks the apps from App time limits until the session ends'),
                      ),
                    const SizedBox(height: 16),
                    GlowButton(label: 'Start focusing', icon: Icons.play_arrow_rounded, onPressed: _start),
                  ] else
                    OutlinedButton.icon(
                      onPressed: () => _stop(),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('End session early'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Today: $todayMinutes focused minutes · ${FocusStore.sessions} sessions all time',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
