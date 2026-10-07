import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/feedback.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/liquid/liquid.dart';
import 'dart:math' as math;

/// Day options for the goal length slider.
const _dayOptions = [7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365];

String _percent(double v) {
  final p = v * 100;
  return p == p.roundToDouble() ? '${p.round()}%' : '${p.toStringAsFixed(1)}%';
}

Future<void> showAddGoalSheet(BuildContext context) {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  double slider = _dayOptions.indexOf(30) / (_dayOptions.length - 1);

  int daysFor(double v) => _dayOptions[(v * (_dayOptions.length - 1)).round()];

  return showLiquidSheet(
    context: context,
    title: 'Set New Goal',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setStateModal) {
        final days = daysFor(slider);
        final target = DateTime.now().add(Duration(days: days));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetLabel('What do you want to achieve?'),
            TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Run a 5K, Read 12 books')),
            const SheetLabel('Why does it matter? (optional)'),
            TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(hintText: 'A reason keeps you going')),
            const SheetLabel('How many days do you need?'),
            BubbleSlider(
              value: slider,
              labelBuilder: (v) => '${daysFor(v)} days',
              onChanged: (v) => setStateModal(() => slider = (v * (_dayOptions.length - 1)).round() / (_dayOptions.length - 1)),
            ),
            const SizedBox(height: 8),
            GlassCard(
              highlighted: true,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.accentOn(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Each day you work on it, tap "I worked on this today" and your goal moves ${_percent(1 / days)} closer. '
                      'Check in every day to finish by ${DateFormat('d MMM yyyy').format(target)}.',
                      style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: 'Save Goal',
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                await Provider.of<GoalProvider>(sheetContext, listen: false).addGoal(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  days: days,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ],
        );
      },
    ),
  );
}

/// Goal list as slivers, for the Plan tab's scroll view.
class GoalsSliver extends StatelessWidget {
  const GoalsSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context);
    final goals = provider.goals;

    if (goals.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 110),
          child: EmptyStateWidget(
            icon: Icons.flag_rounded,
            illustration: IllustrationKind.goals,
            title: 'Set your first goal',
            description: 'Goals are bigger things that take weeks, like "Run a 5K". Choose how many days you need, then check in each day you work on it.',
            buttonText: 'Add a goal',
            onButtonPressed: () => showAddGoalSheet(context),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final goal = goals[index];
            return StaggerIn(key: ValueKey(goal.id), index: index, child: GoalCard(goal: goal));
          },
          childCount: goals.length,
        ),
      ),
    );
  }
}

/// Checks in on a goal and celebrates when it completes.
Future<void> checkInGoal(BuildContext context, Goal goal) async {
  final completed = await Provider.of<GoalProvider>(context, listen: false).toggleCheckIn(goal.id);
  if (completed && context.mounted) {
    showInfoSnackBar(context, 'Goal achieved: "${goal.title}"! Earned +100 XP 🏆');
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;

  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GoalProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = Theme.of(context).textTheme.bodyMedium?.color;
    final accent = AppColors.accentOn(context);
    final done = goal.progress >= 1.0;
    final checkedToday = provider.isCheckedInToday(goal);
    final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      highlighted: done,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.royal : accent.withValues(alpha: isDark ? 0.18 : 0.1)),
                child: Icon(done ? Icons.emoji_events_rounded : Icons.flag_rounded, color: done ? Colors.white : accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? 'Achieved in ${goal.checkInCount} check-ins'
                          : 'Target ${DateFormat('d MMM yyyy').format(goal.targetDate)} · ${daysLeft > 0 ? '$daysLeft days left' : daysLeft == 0 ? 'due today' : 'target date passed'}',
                      style: TextStyle(fontSize: 11.5, color: secondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete goal',
                icon: Icon(Icons.delete_outline_rounded, color: secondary, size: 20),
                onPressed: () {
                  provider.deleteGoal(goal.id);
                  showUndoSnackBar(context, 'Goal deleted', () => provider.restoreGoal(goal));
                },
              ),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(goal.description, style: TextStyle(color: secondary, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ProgressBar(value: goal.progress, track: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE3E6F5))),
              const SizedBox(width: 10),
              Text(_percent(math.min(1.0, goal.progress)), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: accent)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            done ? '🎉 Goal achieved! Great work.' : '${goal.checkInsLeft} more check-ins to go · +${_percent(goal.dailyStep)} each day',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: done ? AppColors.success : secondary),
          ),
          if (!done) ...[
            const SizedBox(height: 14),
            _CheckInButton(checked: checkedToday, onTap: () => checkInGoal(context, goal)),
          ],
        ],
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const _CheckInButton({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!checked) return GlowButton(label: 'I worked on this today', icon: Icons.check_rounded, height: 48, onPressed: onTap);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text('Done for today · tap to undo', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color track;

  const _ProgressBar({required this.value, required this.track});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(height: 10, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(10))),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: math.min(1.0, value)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              height: 10,
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.pink, AppColors.lavender, AppColors.royal]),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
