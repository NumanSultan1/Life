import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/habit_provider.dart';
import '../../models/habit.dart';
import '../../theme/app_colors.dart';
import '../../services/hive_service.dart';
import '../../utils/habit_icons.dart';
import '../../widgets/common/milestone_dialog.dart';
import '../../widgets/liquid/liquid.dart';

Future<void> showAddHabitSheet(BuildContext context) {
  final titleController = TextEditingController();
  String category = 'Health';

  return showLiquidSheet(
    context: context,
    title: 'Add Habit',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setStateModal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetLabel('Habit Title'),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'My daily goal'),
            ),
            const SheetLabel('Choose an Activity'),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconChoiceGrid(options: habitActivities, selected: category, onSelected: (c) => setStateModal(() => category = c)),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      category,
                      key: ValueKey(category),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: GlowButton(
                label: 'Add Habit',
                expand: false,
                onPressed: () {
                  if (titleController.text.trim().isNotEmpty) {
                    final newHabit = Habit(id: DateTime.now().millisecondsSinceEpoch.toString(), title: titleController.text.trim(), category: category);
                    Provider.of<HabitProvider>(sheetContext, listen: false).addHabit(newHabit);
                    Navigator.pop(sheetContext);
                  }
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class HabitsTab extends StatelessWidget {
  const HabitsTab({super.key});

  void _snack(BuildContext context, String text) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HabitProvider>(context);
    final habitList = provider.habits;
    final textTheme = Theme.of(context).textTheme;

    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
    final restoreTokens = box.get('${user}_streakRestoreTokens', defaultValue: 2) as int;
    final xp = box.get('${user}_xp', defaultValue: 0) as int;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Habit Tracker', style: textTheme.titleLarge?.copyWith(fontSize: 26))),
                        GlassPill(text: '$xp XP', icon: Icons.bolt_rounded, color: AppColors.violet),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _ShopTile(
                                icon: Icons.ac_unit_rounded,
                                color: AppColors.sky,
                                title: '$freezers Shields',
                                price: 'Buy · 50 XP',
                                onBuy: xp >= 50
                                    ? () async {
                                        if (await provider.buyStreakFreeze() && context.mounted) _snack(context, 'Bought 1 Streak Freeze! ❄️');
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              _ShopTile(
                                icon: Icons.autorenew_rounded,
                                color: AppColors.accent,
                                title: '$restoreTokens Tokens',
                                price: 'Buy · 80 XP',
                                onBuy: xp >= 80
                                    ? () async {
                                        if (await provider.buyRestoreToken() && context.mounted) _snack(context, 'Bought 1 Streak Restore Token! 🔄');
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SegmentedRing(progress: provider.completionPercentage, size: 132, caption: 'today'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: LiquidSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Today's Habits",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      GlassIconButton(icon: Icons.add_rounded, onTap: () => showAddHabitSheet(context)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (habitList.isEmpty)
                    _EmptyOnLiquid(onAdd: () => showAddHabitSheet(context))
                  else
                    for (var i = 0; i < habitList.length; i++)
                      StaggerIn(
                        key: ValueKey(habitList[i].id),
                        index: i,
                        child: _HabitCard(habit: habitList[i], provider: provider, snack: (t) => _snack(context, t)),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String price;
  final VoidCallback? onBuy;

  const _ShopTile({required this.icon, required this.color, required this.title, required this.price, this.onBuy});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 18,
      onTap: onBuy,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: onBuy != null ? AppColors.accentOn(context) : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOnLiquid extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyOnLiquid({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onLiquid: true,
      onTap: onAdd,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          const Floating(child: Icon(Icons.loop_rounded, size: 44)),
          const SizedBox(height: 12),
          const Text('No Habits Set', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Tap to start building a positive daily habit!', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final HabitProvider provider;
  final ValueChanged<String> snack;

  const _HabitCard({required this.habit, required this.provider, required this.snack});

  @override
  Widget build(BuildContext context) {
    final done = habit.isCompletedToday;
    final hasStreakToRestore = habit.streak == 0 && habit.previousStreak > 0;
    final faded = Colors.white.withValues(alpha: 0.75);

    return GlassCard(
      onLiquid: true,
      highlighted: done,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Pressable(
                pressedScale: 0.85,
                onTap: () => toggleHabitWithMilestone(context, habit),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.navy : Colors.white.withValues(alpha: 0.25),
                    border: Border.all(color: Colors.white.withValues(alpha: done ? 0.3 : 0.5)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: Icon(done ? Icons.check_rounded : habitIcon(habit.category), key: ValueKey(done), size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      done ? 'Completed' : 'Pending',
                      style: TextStyle(fontSize: 12, color: faded, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFC27A)),
                      const SizedBox(width: 2),
                      Text('${habit.streak}d', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  Text('Best ${habit.longestStreak}d', style: TextStyle(fontSize: 11, color: faded)),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded, color: faded, size: 20),
                onPressed: () => provider.deleteHabit(habit.id),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniAction(
                icon: Icons.ac_unit_rounded,
                label: habit.isFrozen ? 'Shield Active' : 'Freeze Streak',
                active: habit.isFrozen,
                onTap: () async {
                  final success = await provider.toggleStreakFreeze(habit.id);
                  if (!success) snack('No Streak Freezers available! Please buy one with XP.');
                },
              ),
              if (hasStreakToRestore) ...[
                const SizedBox(width: 8),
                _MiniAction(
                  icon: Icons.autorenew_rounded,
                  label: 'Restore ${habit.previousStreak}d',
                  active: false,
                  onTap: () async {
                    final success = await provider.restoreStreak(habit.id);
                    snack(success ? 'Streak restored to ${habit.previousStreak} Days! 🎉' : 'No Streak Restore Tokens left! Purchase with XP.');
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MiniAction({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? AppColors.royal : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? AppColors.royal : Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
