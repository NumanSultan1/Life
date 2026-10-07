import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../theme/app_colors.dart';
import '../utils/streak_utils.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  Future<void> _toggleToday(BuildContext context, Habit habit) async {
    final provider = Provider.of<HabitProvider>(context, listen: false);
    final wasCompletedToday = habit.isCompletedToday;
    await provider.toggleHabitCompletion(habit.id);

    // Only celebrate when marking DONE (not when un-marking), and only
    // exactly when a milestone is hit.
    if (wasCompletedToday || !context.mounted) return;
    final updated = provider.habits.where((h) => h.id == habit.id);
    if (updated.isEmpty) return;
    final newStreak = updated.first.streak;
    if (StreakUtils.isMilestone(newStreak)) {
      _showMilestoneDialog(context, updated.first, newStreak);
    }
  }

  void _showMilestoneDialog(BuildContext context, Habit habit, int streak) {
    final label = StreakUtils.milestoneLabel(streak);
    final nextTarget = StreakUtils.nextMilestone(streak);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Milestone',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => const SizedBox(),
      transitionBuilder: (context, anim, _, _) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim.value),
          child: Opacity(
            opacity: anim.value.clamp(0, 1),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardBg : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '$streak',
                        style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 1.0),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'DAY STREAK',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2, color: AppColors.accent),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${habit.title}\nYou just hit a $label milestone!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Next milestone: ${StreakUtils.milestoneLabel(nextTarget)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('KEEP GOING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NEW HABIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.accent)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'e.g. Drink water', border: UnderlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final title = controller.text.trim();
                    if (title.isNotEmpty) {
                      Provider.of<HabitProvider>(context, listen: false).addHabit(
                        Habit(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title),
                      );
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int done, int total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's streak", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$done/$total', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const Text('habits completed today', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = Provider.of<HabitProvider>(context).habits;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeToday = habits.where((h) => h.isCompletedToday).length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(activeToday, habits.length)),
            if (habits.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No habits yet', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final habit = habits[i];
                      final done = habit.isCompletedToday;
                      final streak = habit.streak;
                      final nextTarget = StreakUtils.nextMilestone(streak);
                      final progress = (streak / nextTarget).clamp(0.0, 1.0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCardBg : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(habit.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleToday(context, habit),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: done ? AppColors.accent : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: done ? AppColors.accent : Colors.grey, width: 2),
                                    ),
                                    child: Icon(Icons.check_rounded, color: done ? Colors.white : Colors.grey, size: 22),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 18),
                                const SizedBox(width: 6),
                                Text('$streak day streak', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Text(
                                  'next: ${StreakUtils.milestoneLabel(nextTarget)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: habits.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
