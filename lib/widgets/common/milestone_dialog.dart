import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/streak_utils.dart';
import '../liquid/liquid.dart';

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

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Milestone',
    barrierColor: AppColors.navy.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 450),
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.45), blurRadius: 40, offset: const Offset(0, 18))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: LiquidBackground(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
                      ),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.white),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Floating(
                              distance: 6,
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.22),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                                ),
                                child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFC27A), size: 44),
                              ),
                            ),
                            const SizedBox(height: 18),
                            CountUpText(
                              value: streak,
                              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 1.0, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            const Text('DAY STREAK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
                            const SizedBox(height: 16),
                            Text(
                              '${habit.title}\nYou just hit a $label milestone!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            GlassPill(text: 'Next milestone: ${StreakUtils.milestoneLabel(nextTarget)}', onLiquid: true),
                            const SizedBox(height: 24),
                            Pressable(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                                child: const Text('KEEP GOING', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6, color: AppColors.royal)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
