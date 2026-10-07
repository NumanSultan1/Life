import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/task_provider.dart';
import '../../providers/habit_provider.dart';
import '../../theme/app_colors.dart';
import '../../services/hive_service.dart';
import '../../widgets/dashboard/mood_tracker_card.dart';
import '../../widgets/dashboard/water_tracker_card.dart';
import '../../widgets/dashboard/motivational_quote_card.dart';
import '../../widgets/common/milestone_dialog.dart';
import '../../widgets/liquid/liquid.dart';
import '../../models/habit.dart';
import '../../utils/habit_icons.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  NotificationItem({required this.id, required this.title, required this.body, required this.icon, required this.color});
}

class DashboardTab extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardTab({super.key, required this.onNavigateTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _userName = 'User';
  int _level = 1;
  int _xp = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    setState(() {
      _userName = user;
      _level = box.get('${user}_level', defaultValue: 1) as int;
      _xp = box.get('${user}_xp', defaultValue: 0) as int;
    });
  }

  List<NotificationItem> _getDynamicNotifications() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final habitProvider = Provider.of<HabitProvider>(context, listen: false);
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final List<NotificationItem> items = [];

    // 1. Smart Timed Water Tracker Notification
    final waterIntake = box.get('${user}_waterIntake', defaultValue: 0) as int;
    final currentHour = DateTime.now().hour;

    if (waterIntake < 8) {
      String waterTitle = 'Stay Hydrated! 💧';
      String waterBody = 'You have drunk $waterIntake of 8 glasses today. Keep drinking water!';
      bool shouldShowWaterAlert = true;

      if (currentHour >= 21) {
        // Past 9:00 PM
        if (waterIntake < 8) {
          waterTitle = 'Finish Strong! ⏰💧';
          waterBody = 'It is past 9:00 PM and you have only drunk $waterIntake of 8 glasses. Let\'s reach your daily goal!';
        } else {
          shouldShowWaterAlert = false;
        }
      } else if (currentHour >= 18) {
        // Past 6:00 PM
        if (waterIntake < 6) {
          waterTitle = 'Boost Your Focus! ⏰💧';
          waterBody = 'It is past 6:00 PM and you have only drunk $waterIntake of 6 glasses. Hydration keeps you energized!';
        } else {
          shouldShowWaterAlert = false;
        }
      } else if (currentHour >= 15) {
        // Past 3:00 PM
        if (waterIntake < 4) {
          waterTitle = 'Keep Going! ⏰💧';
          waterBody = 'It is past 3:00 PM and you have only drunk $waterIntake of 4 glasses. A quick glass of water boosts memory!';
        } else {
          shouldShowWaterAlert = false;
        }
      } else if (currentHour >= 12) {
        // Past 12:00 PM
        if (waterIntake < 2) {
          waterTitle = 'Hydration Alert! ⏰💧';
          waterBody = 'It is past 12:00 PM and you have only drunk $waterIntake of 2 glasses. Take a quick sip to stay sharp!';
        } else {
          shouldShowWaterAlert = false;
        }
      }

      if (shouldShowWaterAlert) {
        items.add(NotificationItem(id: 'water_$todayStr', title: waterTitle, body: waterBody, icon: Icons.local_drink_rounded, color: Colors.blue));
      }
    }

    // 2. High Priority Task Notification
    final highPriorityTasks = taskProvider.tasks.where((t) => t.priority == 'High' && !t.isCompleted).toList();
    for (var task in highPriorityTasks) {
      items.add(NotificationItem(id: 'task_${task.id}', title: 'Urgent Task Pending ⚠️', body: 'Do not forget to complete: "${task.title}"', icon: Icons.priority_high_rounded, color: Colors.red));
    }

    // 3. Habit Completion Notification
    final uncompletedHabits = habitProvider.habits.where((h) => !h.isCompletedToday).toList();
    for (var habit in uncompletedHabits) {
      items.add(
        NotificationItem(
          id: 'habit_${habit.id}_$todayStr',
          title: 'Maintain Your Streak! 🔥',
          body: 'You haven\'t completed your "${habit.title}" habit today.',
          icon: Icons.local_fire_department_rounded,
          color: Colors.orange,
        ),
      );
    }

    // 4. Level Up Notification
    final currentLvl = box.get('${user}_level', defaultValue: 1) as int;
    if (currentLvl > 1) {
      items.add(
        NotificationItem(
          id: 'level_$currentLvl',
          title: 'Level $currentLvl Unlocked! 🎉',
          body: 'Congratulations on reaching Level $currentLvl! Keep up the amazing work.',
          icon: Icons.emoji_events_rounded,
          color: Colors.amber,
        ),
      );
    }

    // Filter out dismissed notifications
    final dismissedList = List<String>.from(box.get('${user}_dismissedNotifications', defaultValue: <String>[]) as List);
    return items.where((item) => !dismissedList.contains(item.id)).toList();
  }

  void _dismissNotification(String notificationId) async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final dismissedList = List<String>.from(box.get('${user}_dismissedNotifications', defaultValue: <String>[]) as List);
    if (!dismissedList.contains(notificationId)) {
      dismissedList.add(notificationId);
      await box.put('${user}_dismissedNotifications', dismissedList);
      setState(() {});
    }
  }

  void _dismissAllNotifications(List<NotificationItem> items) async {
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    final dismissedList = List<String>.from(box.get('${user}_dismissedNotifications', defaultValue: <String>[]) as List);
    for (var item in items) {
      if (!dismissedList.contains(item.id)) {
        dismissedList.add(item.id);
      }
    }
    await box.put('${user}_dismissedNotifications', dismissedList);
    setState(() {});
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showLiquidSheet(
      context: context,
      title: 'Notifications',
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final list = _getDynamicNotifications();
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Column(
                    children: [
                      Floating(child: Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.lavender)),
                      SizedBox(height: 12),
                      Text('All caught up!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                        'No new alerts or suggestions at this time.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _dismissAllNotifications(list);
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications cleared')));
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                for (var i = 0; i < list.length; i++)
                  StaggerIn(
                    key: ValueKey(list[i].id),
                    index: i,
                    child: GlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: list[i].color.withValues(alpha: 0.14)),
                            child: Icon(list[i].icon, color: list[i].color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(list[i].title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(list[i].body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () {
                              _dismissNotification(list[i].id);
                              setStateSheet(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData(); // Ensure live level/xp is shown on rebuild
    final taskProvider = Provider.of<TaskProvider>(context);
    final habitProvider = Provider.of<HabitProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayFormatted = DateFormat('EEEE, d MMMM').format(DateTime.now());

    final notificationList = _getDynamicNotifications();
    final unreadCount = notificationList.length;

    final xpNeeded = _level * 100;
    final xpProgress = _xp / xpNeeded;

    final user = HiveService.getCurrentUser();
    final settings = Hive.box(HiveService.settingsBox);
    final water = settings.get('${user}_waterIntake', defaultValue: 0) as int;
    final bestStreak = habitProvider.habits.fold(0, (max, h) => h.streak > max ? h.streak : max);
    final totalItems = taskProvider.totalCount + habitProvider.totalHabits;
    final doneItems = taskProvider.completedCount + habitProvider.completedTodayCount;
    final dayProgress = totalItems == 0 ? 0.0 : doneItems / totalItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StaggerIn(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onNavigateTab(5),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.ringCenterGradient,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
                            ),
                            child: Text(
                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_greeting 👋', style: textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(_userName, style: textTheme.titleLarge?.copyWith(fontSize: 21), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        GlassIconButton(
                          icon: Icons.notifications_none_rounded,
                          onLiquid: false,
                          onTap: () => _showNotificationsBottomSheet(context),
                          badge: unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                                  child: Text(
                                    '$unreadCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StaggerIn(
                              index: 1,
                              child: _MetricRow(icon: Icons.checklist_rounded, color: AppColors.royal, label: 'Tasks', value: '${taskProvider.completedCount}/${taskProvider.totalCount}'),
                            ),
                            StaggerIn(
                              index: 2,
                              child: _MetricRow(icon: Icons.loop_rounded, color: AppColors.accent, label: 'Habits', value: '${habitProvider.completedTodayCount}/${habitProvider.totalHabits}'),
                            ),
                            StaggerIn(
                              index: 3,
                              child: _MetricRow(icon: Icons.local_fire_department_rounded, color: AppColors.warning, label: 'Streak', value: '$bestStreak days'),
                            ),
                            StaggerIn(
                              index: 4,
                              child: _MetricRow(icon: Icons.water_drop_rounded, color: AppColors.sky, label: 'Water', value: '$water/8'),
                            ),
                          ],
                        ),
                      ),
                      SegmentedRing(progress: dayProgress, size: 138, caption: todayFormatted.split(',').first),
                    ],
                  ),
                  const SizedBox(height: 18),
                  StaggerIn(
                    index: 5,
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
                            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('Level $_level Hero', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                    ),
                                    Text('$_xp / $xpNeeded XP', style: textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _GradientBar(value: xpProgress, track: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE3E6F5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                _SheetTitle(title: "Today's Habits", icon: Icons.tune_rounded, onTap: () => widget.onNavigateTab(2)),
                if (habitProvider.habits.isEmpty)
                  GlassCard(
                    onLiquid: true,
                    onTap: () => widget.onNavigateTab(2),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Create your first habit to start a streak', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < habitProvider.habits.length && i < 4; i++)
                    StaggerIn(
                      key: ValueKey('dash_${habitProvider.habits[i].id}'),
                      index: i,
                      child: _DashHabitCard(habit: habitProvider.habits[i]),
                    ),
                const SizedBox(height: 22),
                const MoodTrackerCard(onLiquid: true),
                const SizedBox(height: 14),
                const WaterTrackerCard(onLiquid: true),
                const SizedBox(height: 22),
                const _SheetTitle(title: 'Quick Actions'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    _buildActionCard('Add Task', Icons.add_task_rounded, () => widget.onNavigateTab(1)),
                    _buildActionCard('Add Habit', Icons.loop_rounded, () => widget.onNavigateTab(2)),
                    _buildActionCard('Journal', Icons.edit_note_rounded, () => widget.onNavigateTab(3)),
                    _buildActionCard('Goals', Icons.flag_rounded, () => widget.onNavigateTab(4)),
                    _buildActionCard('Statistics', Icons.bar_chart_rounded, () => widget.onNavigateTab(6)),
                    _buildActionCard('Profile', Icons.person_rounded, () => widget.onNavigateTab(5)),
                  ],
                ),
                const SizedBox(height: 22),
                _SheetTitle(title: "Today's Tasks", icon: Icons.arrow_forward_rounded, onTap: () => widget.onNavigateTab(1)),
                if (taskProvider.tasks.isEmpty)
                  GlassCard(
                    onLiquid: true,
                    onTap: () => widget.onNavigateTab(1),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('No tasks created yet. Tap to add one!', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  )
                else
                  ...taskProvider.tasks.take(3).map((task) {
                    return GlassCard(
                      key: ValueKey('dash_task_${task.id}'),
                      onLiquid: true,
                      highlighted: task.isCompleted,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => taskProvider.toggleTaskStatus(task.id),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: task.isCompleted ? Colors.white : Colors.transparent,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: task.isCompleted ? const Icon(Icons.check_rounded, size: 16, color: AppColors.royal) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, decoration: task.isCompleted ? TextDecoration.lineThrough : null, decorationColor: Colors.white),
                                ),
                                if (task.description.isNotEmpty)
                                  Text(
                                    task.description,
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          GlassPill(text: task.priority, onLiquid: true),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 14),
                const MotivationalQuoteCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(String label, IconData icon, VoidCallback onTap) {
    return GlassCard(
      onLiquid: true,
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MetricRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onTap;

  const _SheetTitle({required this.title, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (icon != null) GlassIconButton(icon: icon!, onTap: onTap, size: 38),
        ],
      ),
    );
  }
}

class _DashHabitCard extends StatelessWidget {
  final Habit habit;

  const _DashHabitCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final done = habit.isCompletedToday;
    return GlassCard(
      onLiquid: true,
      highlighted: done,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => toggleHabitWithMilestone(context, habit),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.navy : Colors.white.withValues(alpha: 0.25)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(done ? Icons.check_rounded : habitIcon(habit.category), key: ValueKey(done), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(done ? 'Completed' : 'Pending', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Text('🔥 ${habit.streak}d', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GradientBar extends StatelessWidget {
  final double value;
  final Color track;

  const _GradientBar({required this.value, required this.track});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(
            height: 7,
            decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(7)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              height: 7,
              width: c.maxWidth * v,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(7)),
            ),
          ),
        ],
      ),
    );
  }
}
