import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/streak_utils.dart';

/// Toggles today's completion for [habit] and shows the milestone
/// celebration when marking it done lands exactly on a milestone.
Future<void> toggleHabitWithMilestone(BuildContext context, Habit habit) async {
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
    showMilestoneDialog(context, updated.first, newStreak);
  }
}

void showMilestoneDialog(BuildContext context, Habit habit, int streak) {
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
                    Text('$streak', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 1.0)),
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
