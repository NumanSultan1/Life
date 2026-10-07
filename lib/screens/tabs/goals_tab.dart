import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/goal.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../services/hive_service.dart';
import '../../widgets/liquid/liquid.dart';
import 'dart:math' as math;

Future<void> showAddGoalSheet(BuildContext context) {
  final titleController = TextEditingController();
  final descController = TextEditingController();

  return showLiquidSheet(
    context: context,
    title: 'Set New Goal',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetLabel('Goal Title'),
        TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(hintText: 'Something worth chasing')),
        const SheetLabel('Description'),
        TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(hintText: 'Why does it matter?')),
        const SizedBox(height: 28),
        GlowButton(
          label: 'Save Goal',
          onPressed: () async {
            if (titleController.text.trim().isNotEmpty) {
              final user = HiveService.getCurrentUser();
              final newGoal = Goal(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                description: descController.text.trim(),
                category: 'Career',
                targetDate: DateTime.now().add(const Duration(days: 30)),
                progress: 0.0,
              );
              await HiveService.saveGoal(newGoal, user);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            }
          },
        ),
      ],
    ),
  );
}

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  Future<void> _updateProgress(Goal goal, double newProgress) async {
    final user = HiveService.getCurrentUser();
    final clampedProgress = double.parse(newProgress.clamp(0.0, 1.0).toStringAsFixed(4));

    final oldProgress = goal.progress;
    final updatedGoal = goal.copyWith(progress: clampedProgress);
    await HiveService.saveGoal(updatedGoal, user);

    // Award 100 XP if the goal has just been completed!
    if (oldProgress < 1.0 && clampedProgress >= 1.0) {
      await HiveService.addXp(100);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal Completed! Earned +100 XP! 🏆')),
        );
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _deleteGoal(String id) async {
    final user = HiveService.getCurrentUser();
    await HiveService.deleteGoal(id, user);
    if (mounted) setState(() {});
  }

  void _showSetProgressSheet(Goal goal) {
    double value = goal.progress;
    showLiquidSheet(
      context: context,
      title: 'Update Progress',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setStateModal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(goal.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
            const SheetLabel('Select your progress'),
            BubbleSlider(
              value: value,
              labelBuilder: (v) => '${(v * 100).round()}%',
              onChanged: (v) => setStateModal(() => value = v),
            ),
            const SizedBox(height: 28),
            GlowButton(
              label: 'Save Progress',
              onPressed: () {
                _updateProgress(goal, value);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addGoal() async {
    await showAddGoalSheet(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final goals = HiveService.getGoals(HiveService.getCurrentUser());
    final completed = goals.where((g) => g.progress >= 1.0).length;
    final average = goals.isEmpty ? 0.0 : goals.fold<double>(0, (sum, g) => sum + math.min(1.0, g.progress)) / goals.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: LiquidHeader(
              title: 'Long-Term Goals',
              subtitle: '$completed of ${goals.length} achieved · ${(average * 100).round()}% average',
              actions: [GlassIconButton(icon: Icons.add_rounded, onTap: _addGoal)],
            ),
          ),
          if (goals.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: EmptyStateWidget(
                  icon: Icons.flag_rounded,
                  title: 'No Goals Set',
                  description: 'Set ambitious targets and track your long-term progress!',
                  buttonText: 'Add Goal',
                  onButtonPressed: _addGoal,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final goal = goals[index];
                    return StaggerIn(
                      key: ValueKey(goal.id),
                      index: index,
                      child: _GoalCard(
                        goal: goal,
                        onSetProgress: () => _showSetProgressSheet(goal),
                        onDelete: () => _deleteGoal(goal.id),
                        onStep: (delta) => _updateProgress(goal, goal.progress + delta),
                      ),
                    );
                  },
                  childCount: goals.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onSetProgress;
  final VoidCallback onDelete;
  final ValueChanged<double> onStep;

  const _GoalCard({required this.goal, required this.onSetProgress, required this.onDelete, required this.onStep});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = Theme.of(context).textTheme.bodyMedium?.color;
    final done = goal.progress >= 1.0;
    final percentStr = (goal.progress * 100).toStringAsFixed(2);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      highlighted: done,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.royal : AppColors.accentOn(context).withValues(alpha: isDark ? 0.18 : 0.1),
                ),
                child: Icon(done ? Icons.emoji_events_rounded : Icons.flag_rounded, color: done ? Colors.white : AppColors.accentOn(context), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Target ${DateFormat('d MMM yyyy').format(goal.targetDate)}', style: TextStyle(fontSize: 11.5, color: secondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Pressable(
                onTap: onSetProgress,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.pink, borderRadius: BorderRadius.circular(10)),
                  child: Text('$percentStr%', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12.5)),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded, color: secondary, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(goal.description, style: TextStyle(color: secondary, fontSize: 13, height: 1.4)),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE3E6F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: math.min(1.0, goal.progress)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(
                    height: 10,
                    width: c.maxWidth * v,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.pink, AppColors.lavender, AppColors.royal]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  done ? '🎉 Goal Completed!' : 'Tap +/- to adjust by 0.25%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: done ? AppColors.success : secondary),
                ),
              ),
              _StepButton(icon: Icons.remove_rounded, tooltip: '-0.25%', onTap: () => onStep(-0.0025)),
              const SizedBox(width: 8),
              _StepButton(icon: Icons.add_rounded, tooltip: '+0.25%', onTap: () => onStep(0.0025)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accentOn(context);
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.85,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
