import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';
import '../services/life_stats.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/illustrations.dart';
import '../widgets/liquid/liquid.dart';
import '../widgets/voice_input_button.dart';

/// Monday-to-today summary with a short reflection saved to the journal.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  final _wentWell = TextEditingController();
  final _nextFocus = TextEditingController();

  @override
  void dispose() {
    _wentWell.dispose();
    _nextFocus.dispose();
    super.dispose();
  }

  Future<void> _save(String weekLabel) async {
    if (_wentWell.text.trim().isEmpty && _nextFocus.text.trim().isEmpty) {
      showInfoSnackBar(context, 'Write at least one line first.');
      return;
    }
    await Provider.of<JournalProvider>(context, listen: false).addEntry(JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Weekly review: $weekLabel',
      content: 'What went well:\n${_wentWell.text.trim()}\n\nFocus for next week:\n${_nextFocus.text.trim()}',
      mood: '😊',
      date: DateTime.now(),
    ));
    if (!mounted) return;
    showInfoSnackBar(context, 'Saved to your journal. +30 XP ✍️');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final stats = LifeStats(context);
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final monday = LifeStats.day(now).subtract(Duration(days: now.weekday - 1));
    final weekDays = LifeStats.days(monday, now);
    final weekLabel = '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(now)}';

    final progress = weekDays.map((d) => stats.dayProgress[LifeStats.key(d)]).whereType<double>().toList();
    final avgProgress = progress.isEmpty ? 0.0 : progress.reduce((a, b) => a + b) / progress.length;
    DateTime? bestDay;
    var bestValue = -1.0;
    for (final d in weekDays) {
      final v = stats.dayProgress[LifeStats.key(d)];
      if (v != null && v > bestValue) {
        bestValue = v;
        bestDay = d;
      }
    }
    final steps = stats.sumBetween(stats.steps, monday, now);
    final sleepDays = weekDays.where((d) => stats.sleepMinutes[LifeStats.key(d)] != null).toList();
    final avgSleep = sleepDays.isEmpty ? null : stats.sumBetween(stats.sleepMinutes, monday, now) / sleepDays.length;
    final mood = stats.averageMood(weekDays.map(LifeStats.key));
    final bestStreak = stats.habits.habits.fold(0, (m, h) => h.streak > m ? h.streak : m);

    final tiles = <(IconData, Color, String, String)>[
      (Icons.donut_large_rounded, AppColors.royal, '${(avgProgress * 100).round()}%', 'Average day'),
      (Icons.task_alt_rounded, AppColors.success, '${stats.tasksDoneBetween(monday, now)}', 'Tasks done'),
      (Icons.local_fire_department_rounded, AppColors.warning, '$bestStreak days', 'Best habit streak'),
      (Icons.directions_walk_rounded, AppColors.sky, NumberFormat.compact().format(steps), 'Steps'),
      (Icons.center_focus_strong_rounded, AppColors.violet, '${stats.sumBetween(stats.focusMinutes, monday, now)} min', 'Focused'),
      (Icons.auto_stories_rounded, AppColors.accent, '${stats.journalBetween(monday, now)}', 'Journal entries'),
      (Icons.bedtime_rounded, AppColors.navy, avgSleep == null ? '—' : '${(avgSleep / 60).toStringAsFixed(1)} h', 'Average sleep'),
      (Icons.mood_rounded, AppColors.pink, mood == null ? '—' : mood.toStringAsFixed(1), 'Average mood (1–5)'),
    ];

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Weekly review',
              subtitle: weekLabel,
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Row(
                      children: [
                        const Illustration(IllustrationKind.allDone, size: 90),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bestDay == null
                                ? 'Your week fills in as you use Life each day.'
                                : 'Your best day was ${DateFormat('EEEE').format(bestDay)} at ${(bestValue * 100).round()}%. ${avgProgress >= 0.7 ? 'Strong week! 💪' : 'Every week is a fresh start.'}',
                            style: textTheme.titleMedium?.copyWith(fontSize: 15, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      for (var i = 0; i < tiles.length; i++)
                        StaggerIn(
                          index: i,
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(tiles[i].$1, color: tiles[i].$2),
                                Text(tiles[i].$3, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: tiles[i].$2)),
                                Text(tiles[i].$4, style: textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Reflect', style: textTheme.titleMedium?.copyWith(fontSize: 17)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SmartTextField(controller: _wentWell, maxLines: 3, hint: 'What went well this week?')),
                    ],
                  ),
                  Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(top: 8), child: VoiceInputButton(controller: _wentWell))),
                  const SizedBox(height: 10),
                  TextField(controller: _nextFocus, maxLines: 2, decoration: const InputDecoration(hintText: 'One thing to focus on next week')),
                  const SizedBox(height: 18),
                  GlowButton(label: 'Save to journal', icon: Icons.auto_stories_rounded, onPressed: () => _save(weekLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
