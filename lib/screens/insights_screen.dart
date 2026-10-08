import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/life_stats.dart';
import '../theme/app_colors.dart';
import '../widgets/illustrations.dart';
import '../widgets/liquid/liquid.dart';

/// How mood lines up with steps, sleep, focus and finishing the day.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static String _emoji(double score) => score >= 4.5 ? '😄' : score >= 3.5 ? '😊' : score >= 2.5 ? '😐' : score >= 1.5 ? '😔' : '😭';

  @override
  Widget build(BuildContext context) {
    final stats = LifeStats(context);
    final moods = stats.moods;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final last14 = LifeStats.days(now.subtract(const Duration(days: 13)), now);

    // Each comparison: label for "good" days, label for the rest, and a test.
    final comparisons = <(IconData, String, String, bool? Function(String))>[
      (Icons.directions_walk_rounded, 'you hit your step goal', 'you didn\'t', (k) => stats.steps[k] == null ? null : stats.steps[k]! >= stats.stepGoal),
      (Icons.bedtime_rounded, 'you slept 7+ hours', 'you slept less', (k) => stats.sleepMinutes[k] == null ? null : stats.sleepMinutes[k]! >= 420),
      (Icons.task_alt_rounded, 'you finished most of your day', 'you finished less', (k) => stats.dayProgress[k] == null ? null : stats.dayProgress[k]! >= 0.8),
      (Icons.center_focus_strong_rounded, 'you had a focus session', 'you didn\'t', (k) => moods.containsKey(k) ? (stats.focusMinutes[k] ?? 0) > 0 : null),
    ];

    final cards = <Widget>[];
    for (final c in comparisons) {
      final good = <String>[], other = <String>[];
      for (final k in moods.keys) {
        final r = c.$4(k);
        if (r == true) good.add(k);
        if (r == false) other.add(k);
      }
      final a = stats.averageMood(good), b = stats.averageMood(other);
      if (good.length >= 2 && other.length >= 2 && a != null && b != null) {
        final diff = ((a - b) / 5 * 100).round();
        cards.add(_InsightCard(
          icon: c.$1,
          title: 'On days ${c.$2}, your mood averages ${a.toStringAsFixed(1)} ${_emoji(a)}',
          body: 'Compared with ${b.toStringAsFixed(1)} ${_emoji(b)} on days ${c.$3}${diff == 0 ? '.' : ' (${diff > 0 ? '+' : ''}$diff%).'}',
          positive: a >= b,
        ));
      }
    }

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Insights',
              subtitle: 'What makes your good days good',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              actions: const [Illustration(IllustrationKind.stats, size: 70)],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mood, last 14 days', style: textTheme.titleMedium?.copyWith(fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (final d in last14)
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(moods[LifeStats.key(d)] ?? '·', style: const TextStyle(fontSize: 18)),
                                    const SizedBox(height: 4),
                                    Text(DateFormat('E').format(d).substring(0, 1), style: textTheme.bodyMedium?.copyWith(fontSize: 10)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Pick a mood on Home each day to fill this in.', style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (cards.isEmpty)
                    GlassCard(
                      child: Column(
                        children: [
                          const Illustration(IllustrationKind.journal, size: 140),
                          Text('Not enough data yet', style: textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            'Log your mood every day for about a week (and track steps, sleep or focus). Insights appear once there are a few days to compare.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    )
                  else
                    ...cards.indexed.map((e) => StaggerIn(index: e.$1, child: e.$2)),
                  const SizedBox(height: 10),
                  Text('Patterns, not proof: other things affect mood too.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final bool positive;

  const _InsightCard({required this.icon, required this.title, required this.body, required this.positive});

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.warning;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3)),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
