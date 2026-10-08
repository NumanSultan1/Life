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
import '../../widgets/illustrations.dart';
import '../../utils/feedback.dart';
import '../arcs/arc_card.dart';
import '../../services/notification_service.dart';

Future<void> showAddHabitSheet(BuildContext context) {
  final titleController = TextEditingController();
  String category = 'Health';
  TimeOfDay? reminder;

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
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: reminder != null,
              secondary: Icon(Icons.notifications_active_rounded, color: AppColors.accentOn(context)),
              title: const Text('Remind me every day', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(reminder == null ? 'Skipped automatically once it\'s done' : 'At ${reminder!.format(context)} · tap to change'),
              onChanged: (v) async {
                if (!v) return setStateModal(() => reminder = null);
                final picked = await pickReminderTime(context, const TimeOfDay(hour: 8, minute: 0));
                if (picked != null) setStateModal(() => reminder = picked);
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: GlowButton(
                label: 'Add Habit',
                expand: false,
                onPressed: () {
                  if (titleController.text.trim().isNotEmpty) {
                    final newHabit = Habit(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      category: category,
                      reminderTime: reminder == null ? '' : formatTimeOfDay(reminder!),
                    );
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

/// 0 = daily habits, 1 = challenges.
final ValueNotifier<int> habitsSegment = ValueNotifier(0);

class HabitsTab extends StatelessWidget {
  const HabitsTab({super.key});

  void _showStreakHelp(BuildContext context) {
    Widget row(IconData icon, Color color, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
    showLiquidSheet(
      context: context,
      title: 'How streaks work',
      builder: (_) => Column(
        children: [
          const Illustration(IllustrationKind.habits, size: 140),
          const SizedBox(height: 8),
          row(
            Icons.local_fire_department_rounded,
            AppColors.warning,
            'Streaks',
            'Mark a habit done each day to grow its streak. Miss a day and it resets to 0. Finishing all of today\'s tasks and habits earns 50 XP (less if you finish part of them).',
          ),
          row(
            Icons.ac_unit_rounded,
            AppColors.sky,
            'Streak freezes (${HabitProvider.freezePrice} XP)',
            'Miss a day? A freeze is used automatically so your streak survives. Each missed habit-day uses one. You start with 2.',
          ),
          row(Icons.autorenew_rounded, AppColors.accent, 'Restore tokens (${HabitProvider.restorePrice} XP)', 'Out of freezes and lost a streak? Use a token to bring it back. You start with 1.'),
          row(Icons.bolt_rounded, AppColors.violet, 'XP to spend', 'Everything you complete adds XP. Spending it in the shop never lowers your level.'),
          row(Icons.emoji_events_rounded, AppColors.violet, 'Milestones', 'Hitting 3, 7, 15, 30 days and beyond shows a celebration.'),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String text) {
    if (context.mounted) showInfoSnackBar(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HabitProvider>(context);
    final habitList = provider.habits;
    final textTheme = Theme.of(context).textTheme;

    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final freezers = box.get('${user}_streakFreezers', defaultValue: 2) as int;
    final restoreTokens = box.get('${user}_streakRestoreTokens', defaultValue: 1) as int;
    final xp = HiveService.getXpBank();

    return ValueListenableBuilder<int>(
      valueListenable: habitsSegment,
      builder: (context, segment, _) => Scaffold(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Habits', style: textTheme.titleLarge?.copyWith(fontSize: 26)),
                                Text('Small things you do every day', style: textTheme.bodyMedium?.copyWith(fontSize: 13)),
                              ],
                            ),
                          ),
                          GlassPill(text: '$xp XP to spend', icon: Icons.bolt_rounded, color: AppColors.violet),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'How streaks work',
                            child: GlassIconButton(icon: Icons.help_outline_rounded, onLiquid: false, size: 38, onTap: () => _showStreakHelp(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _HabitsSegment(value: segment, onChanged: (v) => habitsSegment.value = v),
                      if (segment == 0) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _ShopTile(
                                    icon: Icons.ac_unit_rounded,
                                    color: AppColors.sky,
                                    title: '$freezers Freezes',
                                    price: xp >= HabitProvider.freezePrice ? 'Buy · ${HabitProvider.freezePrice} XP' : 'Used automatically',
                                    onBuy: xp >= HabitProvider.freezePrice
                                        ? () async {
                                            if (await provider.buyStreakFreeze() && context.mounted) {
                                              _snack(context, 'Bought 1 streak freeze ❄️ It will be used automatically.');
                                            }
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 10),
                                  _ShopTile(
                                    icon: Icons.autorenew_rounded,
                                    color: AppColors.accent,
                                    title: '$restoreTokens Restores',
                                    price: xp >= HabitProvider.restorePrice ? 'Buy · ${HabitProvider.restorePrice} XP' : '${HabitProvider.restorePrice} XP each',
                                    onBuy: xp >= HabitProvider.restorePrice
                                        ? () async {
                                            if (await provider.buyRestoreToken() && context.mounted) _snack(context, 'Bought 1 restore token 🔄');
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
                    ],
                  ),
                ),
              ),
            ),
            if (segment == 1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                sliver: SliverList(delegate: SliverChildListDelegate(const [ChallengesList()])),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: LiquidSheet(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Today's Habits",
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                Text('Tap the circle once you\'ve done it today', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                              ],
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: onBuy != null ? AppColors.accentOn(context) : Theme.of(context).textTheme.bodyMedium?.color),
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
          const Illustration(IllustrationKind.habits, size: 150),
          const SizedBox(height: 12),
          const Text('Build your first habit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Habits are things you do every day, like a morning walk. Tap here to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
          ),
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
    final hasStreakToRestore = habit.previousStreak > habit.streak;
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
                tooltip: 'Delete habit',
                onPressed: () {
                  provider.deleteHabit(habit.id);
                  showUndoSnackBar(context, 'Habit deleted', () => provider.addHabit(habit));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniAction(
                icon: habit.reminderTime.isEmpty ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                label: habit.reminderTime.isEmpty ? 'Add reminder' : 'Reminder ${parseTimeOfDay(habit.reminderTime)!.format(context)}',
                active: habit.reminderTime.isNotEmpty,
                onTap: () => _editReminder(context, habit),
              ),
              if (hasStreakToRestore) ...[
                const SizedBox(width: 8),
                _MiniAction(
                  icon: Icons.autorenew_rounded,
                  label: 'Restore ${habit.previousStreak}-day streak',
                  active: false,
                  onTap: () async {
                    final success = await provider.restoreStreak(habit.id);
                    snack(success ? 'Streak restored! 🎉' : 'No restore tokens left. Buy one for ${HabitProvider.restorePrice} XP.');
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

/// Asks for notification permission, then lets the user pick a time.
Future<TimeOfDay?> pickReminderTime(BuildContext context, TimeOfDay initial) async {
  if (!await NotificationService.requestPermission()) {
    if (context.mounted) showInfoSnackBar(context, 'Notifications are off for Life. Turn them on in your phone settings.');
    return null;
  }
  if (!context.mounted) return null;
  return showLiquidTimePicker(context, initialTime: initial, title: 'Daily reminder time');
}

Future<void> _editReminder(BuildContext context, Habit habit) async {
  final provider = Provider.of<HabitProvider>(context, listen: false);
  final current = parseTimeOfDay(habit.reminderTime);
  if (current != null) {
    final remove = await showLiquidActions<bool>(
      context,
      title: 'Reminder at ${current.format(context)}',
      actions: const [LiquidAction(false, 'Change time', Icons.schedule_rounded), LiquidAction(true, 'Turn off reminder', Icons.notifications_off_rounded, destructive: true)],
    );
    if (remove == null) return;
    if (remove) {
      await provider.setReminder(habit.id, null);
      return;
    }
  }
  if (!context.mounted) return;
  final picked = await pickReminderTime(context, current ?? const TimeOfDay(hour: 8, minute: 0));
  if (picked != null) {
    await provider.setReminder(habit.id, picked);
    if (context.mounted) showInfoSnackBar(context, 'Reminder set for ${picked.format(context)} every day 🔔');
  }
}

class _HabitsSegment extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _HabitsSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const labels = [('Daily habits', Icons.loop_rounded), ('Challenges', Icons.emoji_events_rounded)];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              left: value * c.maxWidth / 2,
              top: 0,
              bottom: 0,
              width: c.maxWidth / 2,
              child: Container(
                decoration: BoxDecoration(color: AppColors.royal, borderRadius: BorderRadius.circular(14)),
              ),
            ),
            // Fill the whole height so labels sit in the middle.
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == i,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(labels[i].$2, size: 18, color: value == i ? Colors.white : AppColors.accentOn(context)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  labels[i].$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.1, color: value == i ? Colors.white : AppColors.accentOn(context)),
                                  textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
