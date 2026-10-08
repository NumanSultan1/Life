import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/focus_store.dart';
import '../services/hive_service.dart';
import '../services/life_stats.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';

/// A badge with a rule over the user's history. [progress] returns
/// (current, target).
class Achievement {
  final String id, title, description, category;
  final IconData icon;
  final Color color;
  final (int, int) Function(LifeStats s) progress;

  const Achievement(this.id, this.title, this.description, this.icon, this.color, this.progress, {this.category = ''});

  bool unlocked(LifeStats s) {
    final (cur, target) = progress(s);
    return cur >= target;
  }
}

int _max(Iterable<int> xs) => xs.fold(0, (m, v) => v > m ? v : m);
int _perfectDays(LifeStats s) => s.dayProgress.values.where((v) => v >= 1).length;
int _bestStreak(LifeStats s) => _max(s.habits.habits.map((h) => h.longestStreak > h.streak ? h.longestStreak : h.streak));
int _bestDaySteps(LifeStats s) => _max(s.steps.values);
int _totalSteps(LifeStats s) => s.steps.values.fold(0, (a, b) => a + b);
int _goodSleepNights(LifeStats s) => s.sleepMinutes.values.where((m) => m >= 420).length;
int _focusMinutes(LifeStats s) => s.focusMinutes.values.fold(0, (a, b) => a + b);
int _greatMoodDays(LifeStats s) => s.moods.values.where((m) => (LifeStats.moodScore[m] ?? 0) >= 4).length;

int _bestWeekSteps(LifeStats s) {
  final now = DateTime.now();
  var best = 0;
  for (var i = 0; i < 60; i++) {
    final end = now.subtract(Duration(days: i));
    final total = s.sumBetween(s.steps, end.subtract(const Duration(days: 6)), end);
    if (total > best) best = total;
  }
  return best;
}

int _bestArcRun(LifeStats s) {
  var best = 0;
  for (final a in s.arcs.allChallenges) {
    final current = s.arcs.isJoined(a.id) ? (a.strict ? s.arcs.dayNumber(a.id) - 1 : s.arcs.completedDays(a.id)) : 0;
    best = [best, s.arcs.bestRun(a.id), current].reduce((x, y) => x > y ? x : y);
  }
  return best;
}

final _gold = const Color(0xFFD4A017);

/// One tier per (target, title); the description is built from [describe].
List<Achievement> _tiers(String id, String category, IconData icon, Color color, int Function(LifeStats) value, String Function(int) describe, List<(int, String)> tiers) => [
      for (final (target, title) in tiers)
        Achievement('${id}_$target', title, describe(target), icon, color, (s) => (value(s), target), category: category),
    ];

String _n(int v) => v >= 1000000 ? '${v ~/ 1000000} million' : v >= 1000 && v % 1000 == 0 ? '${v ~/ 1000},000' : '$v';

final achievements = <Achievement>[
  ..._tiers('tasks', 'Tasks', Icons.task_alt_rounded, AppColors.royal, (s) => s.tasks.completedCount, (t) => t == 1 ? 'Complete your first task' : 'Complete ${_n(t)} tasks', [
    (1, 'First step'), (5, 'Warming up'), (10, 'Task tamer'), (25, 'Busy bee'), (50, 'Getting things done'),
    (100, 'Centurion'), (250, 'Productivity pro'), (500, 'Machine'), (1000, 'Legend of lists'),
  ]),
  ..._tiers('streak', 'Habits', Icons.local_fire_department_rounded, AppColors.warning, _bestStreak, (t) => 'Reach a $t-day habit streak', [
    (3, 'Spark'), (7, 'On a roll'), (14, 'Two strong weeks'), (21, 'Habit formed'), (30, 'Unstoppable'), (50, 'Blazing'),
    (75, 'Inferno'), (100, 'Triple digits'), (150, 'Iron routine'), (200, 'Way of life'), (365, 'A whole year'),
  ]),
  ..._tiers('habits', 'Habits', Icons.loop_rounded, AppColors.warning, (s) => s.habits.totalHabits, (t) => t == 1 ? 'Create your first habit' : 'Keep $t habits going', [
    (1, 'Habit maker'), (3, 'Routine builder'), (5, 'Life designer'), (8, 'System thinker'),
  ]),
  ..._tiers('goals', 'Goals', Icons.emoji_events_rounded, AppColors.success, (s) => s.goals.completedCount, (t) => t == 1 ? 'Achieve a goal' : 'Achieve $t goals', [
    (1, 'Goal getter'), (3, 'Hat-trick'), (5, 'High achiever'), (10, 'Dream chaser'), (20, 'Mountain mover'),
  ]),
  ..._tiers('goalset', 'Goals', Icons.flag_rounded, AppColors.success, (s) => s.goals.goals.length, (t) => t == 1 ? 'Set your first goal' : 'Set $t goals', [
    (1, 'Aim high'), (5, 'Big plans'), (10, 'Visionary'),
  ]),
  ..._tiers('journal', 'Journal', Icons.auto_stories_rounded, AppColors.accent, (s) => s.journal.allEntries.length, (t) => t == 1 ? 'Write your first journal entry' : 'Write $t journal entries', [
    (1, 'Dear diary'), (5, 'Storyteller'), (10, 'Reflective'), (25, 'Thinker'), (50, 'Author'), (100, 'Memoirist'), (200, 'Library of you'),
  ]),
  ..._tiers('mood', 'Mood', Icons.mood_rounded, AppColors.pink, (s) => s.moods.length, (t) => t == 1 ? 'Log your mood once' : 'Log your mood on $t days', [
    (1, 'Checking in'), (7, 'Self-aware'), (14, 'In tune'), (30, 'Mood mapper'), (60, 'Know thyself'), (100, 'Emotional athlete'), (200, 'Inner compass'), (365, 'Year of feelings'),
  ]),
  ..._tiers('happy', 'Mood', Icons.sentiment_very_satisfied_rounded, AppColors.pink, _greatMoodDays, (t) => 'Feel good or great on $t days', [
    (5, 'Good vibes'), (20, 'Sunny side'), (50, 'Joy collector'), (100, 'Radiant'),
  ]),
  ..._tiers('daysteps', 'Steps', Icons.directions_walk_rounded, AppColors.sky, _bestDaySteps, (t) => 'Walk ${_n(t)} steps in one day', [
    (5000, 'Stroller'), (8000, 'Walker'), (10000, '10K club'), (12000, 'Strider'), (15000, 'Trekker'), (20000, 'Marathoner'), (25000, 'Road runner'), (30000, 'Ultra'),
  ]),
  ..._tiers('weeksteps', 'Steps', Icons.hiking_rounded, AppColors.sky, _bestWeekSteps, (t) => 'Walk ${_n(t)} steps in 7 days', [
    (35000, 'Weekly wanderer'), (50000, 'Pathfinder'), (70000, 'Road warrior'), (100000, 'Explorer'), (150000, 'Globetrotter'),
  ]),
  ..._tiers('totalsteps', 'Steps', Icons.public_rounded, AppColors.sky, _totalSteps, (t) => 'Walk ${_n(t)} steps in total', [
    (100000, 'First 100K'), (250000, 'Quarter million'), (500000, 'Half a million'), (1000000, 'Millionaire'), (2000000, 'Around the city'),
  ]),
  ..._tiers('sleep', 'Sleep', Icons.bedtime_rounded, AppColors.navy, _goodSleepNights, (t) => t == 1 ? 'Sleep 7+ hours one night' : 'Sleep 7+ hours on $t nights', [
    (1, 'Well rested'), (7, 'Sleep week'), (14, 'Dream team'), (30, 'Night owl no more'), (60, 'Sleep master'), (100, 'Recharged'),
  ]),
  ..._tiers('focus', 'Focus', Icons.center_focus_strong_rounded, AppColors.violet, (_) => FocusStore.sessions, (t) => t == 1 ? 'Finish a focus session' : 'Finish $t focus sessions', [
    (1, 'In the zone'), (5, 'Concentrated'), (10, 'Deep worker'), (25, 'Laser focus'), (50, 'Flow state'), (100, 'Monk mode'), (250, 'Zen master'),
  ]),
  ..._tiers('focusmin', 'Focus', Icons.timer_rounded, AppColors.violet, _focusMinutes, (t) => 'Focus for ${t >= 60 ? '${t ~/ 60} hours' : '$t minutes'} in total', [
    (60, 'First hour'), (300, 'Five hours'), (600, 'Ten hours'), (1500, 'Twenty-five hours'), (3000, 'Fifty hours'), (6000, 'Hundred hours'),
  ]),
  ..._tiers('arc', 'Challenges', Icons.lock_rounded, AppColors.navy, _bestArcRun, (t) => 'Keep a challenge going for $t days', [
    (3, 'Committed'), (7, 'Locked in'), (14, 'Disciplined'), (21, 'Relentless'), (30, 'Iron will'), (50, 'Warrior'), (75, '75 strong'), (100, 'Titan'),
  ]),
  ..._tiers('arcdone', 'Challenges', Icons.workspace_premium_rounded, _gold, (s) => s.arcs.allChallenges.where((a) => s.arcs.isFinished(a.id) || s.arcs.bestRun(a.id) >= a.lengthDays).length, (t) => t == 1 ? 'Finish a whole challenge' : 'Finish $t different challenges', [
    (1, 'Arc complete'), (2, 'Double arc'), (3, 'Seasoned'), (5, 'Champion'),
  ]),
  Achievement('arc_custom', 'Rule maker', 'Create your own challenge', Icons.edit_note_rounded, AppColors.navy, (s) => (s.arcs.customChallenges.length, 1), category: 'Challenges'),
  ..._tiers('perfect', 'Perfect days', Icons.star_rounded, _gold, _perfectDays, (t) => t == 1 ? 'Finish everything planned for a day' : 'Have $t perfect days', [
    (1, 'Perfect day'), (3, 'Hat-trick of stars'), (7, 'Perfect week'), (14, 'Star student'), (30, 'Perfect month'), (50, 'Constellation'), (100, 'Galaxy'), (200, 'Superstar'),
  ]),
  ..._tiers('level', 'Level', Icons.military_tech_rounded, AppColors.violet, (s) => s.level, (t) => 'Reach level $t', [
    (2, 'Level up'), (3, 'Rising'), (5, 'Level 5'), (7, 'Lucky seven'), (10, 'Double digits'), (15, 'Veteran'), (20, 'Elite'), (25, 'Master'), (30, 'Grandmaster'), (40, 'Mythic'), (50, 'Legendary'),
  ]),
];

/// Celebrates badges unlocked since the last check (called from Home).
void checkNewAchievements(BuildContext context) {
  final box = Hive.box(HiveService.settingsBox);
  final key = '${HiveService.getCurrentUser()}_achievements';
  final known = Set<String>.from((box.get(key) as List?) ?? const []);
  final stats = LifeStats(context);
  final now = achievements.where((a) => a.unlocked(stats)).map((a) => a.id).toSet();
  final fresh = now.difference(known);
  if (fresh.isEmpty) return;
  box.put(key, now.union(known).toList());
  // First run (or a new badge set): record what's already earned quietly.
  if (box.get('${key}_version') != 2) {
    box.put('${key}_version', 2);
    return;
  }
  final a = achievements.firstWhere((x) => fresh.contains(x.id));
  showInfoSnackBar(context, '🏅 Achievement unlocked: ${a.title}${fresh.length > 1 ? ' (+${fresh.length - 1} more)' : ''}');
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = LifeStats(context);
    final unlocked = achievements.where((a) => a.unlocked(stats)).length;
    final categories = <String>{for (final a in achievements) a.category}.toList();
    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Achievements',
              subtitle: '$unlocked of ${achievements.length} unlocked',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: unlocked / achievements.length, minHeight: 10, color: AppColors.royal, backgroundColor: AppColors.royal.withValues(alpha: 0.14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${(unlocked * 100 / achievements.length).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ),
            for (final category in categories) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
                child: Row(
                  children: [
                    Expanded(child: Text(category, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17))),
                    Text(
                      '${achievements.where((a) => a.category == category && a.unlocked(stats)).length}/${achievements.where((a) => a.category == category).length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.64,
                  children: [
                    for (final a in achievements.where((a) => a.category == category)) _Badge(a: a, stats: stats),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Achievement a;
  final LifeStats stats;

  const _Badge({required this.a, required this.stats});

  @override
  Widget build(BuildContext context) {
    final (cur, target) = a.progress(stats);
    final done = cur >= target;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '${a.title}, ${done ? 'unlocked' : 'locked, $cur of $target'}. ${a.description}',
      child: GlassCard(
        highlighted: done,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? LinearGradient(colors: [a.color, a.color.withValues(alpha: 0.6)]) : null,
                color: done ? null : textTheme.bodyMedium?.color?.withValues(alpha: 0.12),
                boxShadow: done ? [BoxShadow(color: a.color.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))] : null,
              ),
              child: Icon(done ? a.icon : Icons.lock_outline_rounded, color: done ? Colors.white : textTheme.bodyMedium?.color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(a.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, height: 1.2)),
            const SizedBox(height: 3),
            Text(a.description, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium?.copyWith(fontSize: 10.5, height: 1.25)),
            const Spacer(),
            if (!done)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: target == 0 ? 0 : (cur / target).clamp(0.0, 1.0), minHeight: 5, color: a.color, backgroundColor: a.color.withValues(alpha: 0.15)),
              ),
          ],
        ),
      ),
    );
  }
}
