import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../widgets/liquid/liquid.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final habitProvider = Provider.of<HabitProvider>(context);
    final journalProvider = Provider.of<JournalProvider>(context);

    final user = HiveService.getCurrentUser();
    final goals = HiveService.getGoals(user);

    final taskRate = taskProvider.totalCount == 0
        ? 0
        : ((taskProvider.completedCount / taskProvider.totalCount) * 100).toInt();

    final habitRate = (habitProvider.completionPercentage * 100).toInt();

    final stats = [
      ('Tasks Completed', taskProvider.completedCount, '', Icons.check_circle_rounded, AppColors.royal),
      ('Habit Completion Rate', habitRate, '%', Icons.loop_rounded, AppColors.violet),
      ('Journal Reflections', journalProvider.entries.length, '', Icons.auto_stories_rounded, AppColors.sky),
      ('Active Goals', goals.length, '', Icons.flag_rounded, AppColors.accent),
    ];

    return Scaffold(
      body: AmbientBackground(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiquidHeader(
                title: 'Live Analytics',
                subtitle: 'Your productivity at a glance',
                leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggerIn(
                      child: GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Live Productivity Rate', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${taskProvider.completedCount} of ${taskProvider.totalCount} tasks completed',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            SegmentedRing(progress: taskRate / 100, size: 120),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Real-Time Activity Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        for (var i = 0; i < stats.length; i++)
                          StaggerIn(
                            index: i + 1,
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: stats[i].$5.withValues(alpha: 0.14)),
                                    child: Icon(stats[i].$4, color: stats[i].$5, size: 22),
                                  ),
                                  CountUpText(
                                    value: stats[i].$2,
                                    suffix: stats[i].$3,
                                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: stats[i].$5),
                                  ),
                                  Text(stats[i].$1, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
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
