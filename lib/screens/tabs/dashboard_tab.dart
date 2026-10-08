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
import '../../models/task.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../widgets/illustrations.dart';
import '../../services/notification_service.dart';
import '../../services/progress_history.dart';
import '../../services/reminder_settings.dart';
import '../../utils/feedback.dart';
import '../profile_screen.dart';
import 'goals_tab.dart';
import 'habits_tab.dart';
import 'plan_tab.dart';
import 'tasks_tab.dart';

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
  String _userName = '';
  int _level = 1;
  int _xp = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // After the first frame: overnight streak news, then the reminders prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupMessages());
  }

  Future<void> _showStartupMessages() async {
    if (!mounted) return;
    final events = Provider.of<HabitProvider>(context, listen: false).takePendingEvents();
    if (events.isNotEmpty) {
      await showLiquidSheet(
        context: context,
        title: 'While you were away',
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in events)
              GlassCard(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), child: Text(e, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
            const SizedBox(height: 8),
            GlowButton(label: 'Got it', onPressed: () => Navigator.pop(sheetContext)),
          ],
        ),
      );
    }
    if (!mounted || ReminderSettings.prompted) return;
    await ReminderSettings.markPrompted();
    if (!mounted) return;
    await showLiquidSheet(
      context: context,
      title: 'Stay on track',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Illustration(IllustrationKind.allDone, size: 140)),
          const SizedBox(height: 8),
          const Text('Turn on reminders?', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Life can send you a daily check-in at 8 PM and remind you about tasks and habits at the times you choose. You can change this anytime in Profile.',
            textAlign: TextAlign.center,
            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 22),
          GlowButton(
            label: 'Turn on reminders',
            icon: Icons.notifications_active_rounded,
            onPressed: () async {
              Navigator.pop(sheetContext);
              if (await NotificationService.requestPermission()) {
                await ReminderSettings.setDailyCheckIn(const TimeOfDay(hour: 20, minute: 0));
                if (mounted) showInfoSnackBar(context, 'Reminders on. Daily check-in at 8:00 PM 🔔');
              } else if (mounted) {
                showInfoSnackBar(context, 'Notifications are blocked. You can allow them in your phone settings.');
              }
            },
          ),
          TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Not now')),
        ],
      ),
    );
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
    final highPriorityTasks = taskProvider.todayTasks.where((t) => t.priority == 'High' && !t.isCompleted).toList();
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

    // 4. Streak freezes used or streaks lost today
    final streakEvents = List<String>.from(box.get('${user}_streakEvents_$todayStr', defaultValue: <String>[]) as List);
    for (var i = 0; i < streakEvents.length; i++) {
      final saved = streakEvents[i].startsWith('❄️');
      items.add(
        NotificationItem(
          id: 'streak_${todayStr}_$i',
          title: saved ? 'Streak freeze used ❄️' : 'Streak lost 💔',
          body: streakEvents[i].substring(3),
          icon: saved ? Icons.ac_unit_rounded : Icons.heart_broken_rounded,
          color: saved ? Colors.lightBlue : Colors.pink,
        ),
      );
    }

    // 5. Goals not checked in yet today
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    for (final goal in goalProvider.activeGoals.where((g) => !goalProvider.isCheckedInToday(g))) {
      items.add(
        NotificationItem(
          id: 'goal_${goal.id}_$todayStr',
          title: 'Did you work on "${goal.title}"? 🎯',
          body: 'Check in today to move it ${(goal.dailyStep * 100).toStringAsFixed(1)}% closer.',
          icon: Icons.flag_rounded,
          color: Colors.deepPurple,
        ),
      );
    }

    // 6. Level Up Notification
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
                      Illustration(IllustrationKind.allDone, size: 150),
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

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openGoals() {
    planSegment.value = 1;
    widget.onNavigateTab(1);
  }

  void _openTasks() {
    planSegment.value = 0;
    widget.onNavigateTab(1);
  }

  void _showHowItWorks() {
    showLiquidSheet(
      context: context,
      title: 'How it works',
      builder: (sheetContext) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HowRow(icon: Icons.checklist_rounded, title: 'Tasks', text: 'One-off things to do. Tick them off when they are done.'),
          _HowRow(icon: Icons.loop_rounded, title: 'Habits', text: 'Things you repeat every day. Each day in a row grows your streak 🔥 and earns 15 XP.'),
          _HowRow(icon: Icons.flag_rounded, title: 'Goals', text: 'Big things over weeks. Check in each day you work on one to move it forward (+10 XP).'),
          _HowRow(icon: Icons.auto_stories_rounded, title: 'Journal', text: 'Write how your day went. Each entry earns 30 XP.'),
          _HowRow(icon: Icons.emoji_events_rounded, title: 'XP & levels', text: 'Everything you complete earns XP. Fill the bar to level up.'),
          _HowRow(icon: Icons.ac_unit_rounded, title: 'Streak freezes', text: 'Miss a day and a freeze is used automatically, so your streak survives. You start with 2; buy more for 500 XP.'),
          _HowRow(icon: Icons.autorenew_rounded, title: 'Restore tokens', text: 'Out of freezes and lost a streak? A restore token brings it back. You start with 1; buy more for 700 XP.'),
          _HowRow(icon: Icons.notifications_active_rounded, title: 'Reminders', text: 'Set a time on any task or habit and Life will notify you. Turn on a daily check-in in Profile.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData(); // Ensure live level/xp is shown on rebuild
    final taskProvider = Provider.of<TaskProvider>(context);
    final habitProvider = Provider.of<HabitProvider>(context);
    final goalProvider = Provider.of<GoalProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final notificationList = _getDynamicNotifications();
    final unreadCount = notificationList.length;

    final xpNeeded = _level * 100;
    final xpProgress = _xp / xpNeeded;

    // Everything that can be completed today counts toward the ring.
    final goalsToday = goalProvider.activeGoals.length + goalProvider.goals.where((g) => g.progress >= 1.0 && goalProvider.isCheckedInToday(g)).length;
    final goalsDone = goalProvider.goals.where(goalProvider.isCheckedInToday).length;
    final todayTasks = taskProvider.todayTasks;
    final totalItems = todayTasks.length + habitProvider.totalHabits + goalsToday;
    final doneItems = taskProvider.todayCompletedCount + habitProvider.completedTodayCount + goalsDone;
    // Remember today's result so the weekly chart below includes it.
    // (Hive updates its in-memory copy synchronously; it only writes when
    // the numbers change.)
    ProgressHistory.recordToday(doneItems, totalItems);
    final dayProgress = totalItems == 0 ? 0.0 : doneItems / totalItems;

    // Only the built-in water task means the user hasn't added tasks yet.
    final hasOwnTask = taskProvider.hasOwnTasks;
    final setupSteps = [
      (Icons.add_task_rounded, 'Add a task', 'Something to get done today', hasOwnTask, () => showAddTaskSheet(context)),
      (Icons.loop_rounded, 'Create a habit', 'Something to repeat every day', habitProvider.totalHabits > 0, () => showAddHabitSheet(context)),
      (Icons.flag_rounded, 'Set a goal', 'Something big to work toward', goalProvider.goals.isNotEmpty, () => showAddGoalSheet(context)),
    ];
    final setupLeft = setupSteps.where((s) => !s.$4).length;

    final openTasks = todayTasks.where((t) => !t.isCompleted).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaggerIn(
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Open profile',
                          child: GestureDetector(
                            onTap: _openProfile,
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
                                  child: Text('$unreadCount', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Today at a glance: one ring for everything, plus level.
                  StaggerIn(
                    index: 1,
                    child: GlassCard(
                      onTap: () => widget.onNavigateTab(6),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SegmentedRing(progress: dayProgress, size: 104, caption: 'today'),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  totalItems == 0
                                      ? "Let's plan your day"
                                      : doneItems == totalItems
                                          ? 'All done for today! 🎉'
                                          : '$doneItems of $totalItems done today',
                                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text('Tasks, habits and goal check-ins all count.', style: textTheme.bodyMedium?.copyWith(fontSize: 12.5, height: 1.3)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text('Level $_level', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.accentOn(context))),
                                    const SizedBox(width: 8),
                                    Expanded(child: _GradientBar(value: xpProgress, track: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE3E6F5))),
                                    const SizedBox(width: 8),
                                    Text('$_xp/$xpNeeded XP', style: textTheme.bodyMedium?.copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  StaggerIn(index: 2, child: _WeeklyProgressCard(onTap: () => widget.onNavigateTab(6))),
                  if (setupLeft > 0) ...[
                    const SizedBox(height: 14),
                    StaggerIn(index: 2, child: _GetStartedCard(steps: setupSteps, onHowItWorks: _showHowItWorks)),
                  ],
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
                _SheetTitle(title: 'Today', subtitle: 'Tap anything to mark it done', icon: Icons.help_outline_rounded, iconLabel: 'How it works', onTap: _showHowItWorks),
                if (totalItems > 0 && doneItems == totalItems)
                  GlassCard(
                    onLiquid: true,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Illustration(IllustrationKind.allDone, size: 90),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text("You've finished everything for today. Enjoy the rest of your day!", style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w700, height: 1.4)),
                        ),
                      ],
                    ),
                  ),

                // Habits
                _SectionLabel(label: 'Habits to keep', action: 'See all', onAction: () => widget.onNavigateTab(2)),
                if (habitProvider.habits.isEmpty)
                  _EmptyRow(icon: Icons.loop_rounded, text: 'No habits yet. Create one to start a streak.', onTap: () => showAddHabitSheet(context))
                else
                  for (var i = 0; i < habitProvider.habits.length && i < 5; i++)
                    StaggerIn(key: ValueKey('dash_${habitProvider.habits[i].id}'), index: i, child: _DashHabitCard(habit: habitProvider.habits[i])),

                // Tasks
                const SizedBox(height: 10),
                _SectionLabel(label: 'Tasks', action: 'See all', onAction: _openTasks),
                if (todayTasks.isEmpty)
                  _EmptyRow(icon: Icons.add_task_rounded, text: 'No tasks yet. Add something to do today.', onTap: () => showAddTaskSheet(context))
                else if (openTasks.isEmpty)
                  _EmptyRow(icon: Icons.check_circle_rounded, text: 'Every task is done. Nice!', onTap: _openTasks)
                else
                  ...openTasks.take(4).map((task) => _DashTaskRow(key: ValueKey('dash_task_${task.id}'), task: task)),

                // Goals
                const SizedBox(height: 10),
                _SectionLabel(label: 'Goal check-ins', action: 'See all', onAction: _openGoals),
                if (goalProvider.goals.isEmpty)
                  _EmptyRow(icon: Icons.flag_rounded, text: 'No goals yet. Set one to work toward.', onTap: () => showAddGoalSheet(context))
                else if (goalProvider.activeGoals.isEmpty)
                  _EmptyRow(icon: Icons.emoji_events_rounded, text: 'All your goals are achieved!', onTap: _openGoals)
                else
                  ...goalProvider.activeGoals.take(3).map((g) => _DashGoalRow(key: ValueKey('dash_goal_${g.id}'), goal: g, checked: goalProvider.isCheckedInToday(g))),

                const SizedBox(height: 22),
                const _SectionLabel(label: 'Check in with yourself'),
                const MoodTrackerCard(onLiquid: true),
                const SizedBox(height: 14),
                const WaterTrackerCard(onLiquid: true),
                const SizedBox(height: 14),
                GlassCard(
                  onLiquid: true,
                  onTap: () => widget.onNavigateTab(6),
                  child: const Row(
                    children: [
                      Illustration(IllustrationKind.stats, size: 64),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('See your progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Stats for tasks, habits, journal and goals', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const MotivationalQuoteCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HowRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _HowRow({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentOn(context).withValues(alpha: 0.14)),
            child: Icon(icon, color: AppColors.accentOn(context), size: 20),
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
  }
}

/// Three-step checklist shown until the user has a task, habit and goal.
class _GetStartedCard extends StatelessWidget {
  final List<(IconData, String, String, bool, VoidCallback)> steps;
  final VoidCallback onHowItWorks;

  const _GetStartedCard({required this.steps, required this.onHowItWorks});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = steps.where((s) => s.$4).length;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Illustration(IllustrationKind.welcome, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Get started · $done of 3', style: textTheme.titleMedium?.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Set up your day in three quick steps.', style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final s in steps)
            Pressable(
              onTap: s.$4 ? null : s.$5,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: s.$4 ? AppColors.success : AppColors.accentOn(context).withValues(alpha: 0.12)),
                      child: Icon(s.$4 ? Icons.check_rounded : s.$1, size: 18, color: s.$4 ? Colors.white : AppColors.accentOn(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.$2,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, decoration: s.$4 ? TextDecoration.lineThrough : null),
                          ),
                          Text(s.$3, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!s.$4) Icon(Icons.chevron_right_rounded, color: textTheme.bodyMedium?.color),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onHowItWorks,
              icon: Icon(Icons.help_outline_rounded, size: 18, color: AppColors.accentOn(context)),
              label: Text('How does this app work?', style: TextStyle(color: AppColors.accentOn(context), fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? iconLabel;
  final VoidCallback? onTap;

  const _SheetTitle({required this.title, this.subtitle, this.icon, this.iconLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                if (subtitle != null) Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (icon != null) Tooltip(message: iconLabel ?? '', child: GlassIconButton(icon: icon!, onTap: onTap, size: 40)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? action;
  final VoidCallback? onAction;

  const _SectionLabel({required this.label, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(action!, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _EmptyRow({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onLiquid: true,
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
          const Icon(Icons.chevron_right_rounded, size: 20),
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
      margin: const EdgeInsets.only(bottom: 10),
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
                Text(done ? 'Done today' : 'Tap when done', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Text('🔥 ${habit.streak}d', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DashTaskRow extends StatelessWidget {
  final Task task;

  const _DashTaskRow({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    return GlassCard(
      onLiquid: true,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => provider.toggleTaskStatus(task.id),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (task.description.isNotEmpty)
                  Text(task.description, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GlassPill(text: task.priority, onLiquid: true),
        ],
      ),
    );
  }
}

class _DashGoalRow extends StatelessWidget {
  final Goal goal;
  final bool checked;

  const _DashGoalRow({super.key, required this.goal, required this.checked});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onLiquid: true,
      highlighted: checked,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: AppColors.pink,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: () => checkInGoal(context, goal),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: checked ? Colors.white : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Text(
                checked ? '✓ Done' : 'Worked on it',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: checked ? AppColors.royal : Colors.white),
              ),
            ),
          ),
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
          Container(height: 7, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(7))),
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

/// Monday-to-Sunday completion bars for the current week.
class _WeeklyProgressCard extends StatelessWidget {
  final VoidCallback onTap;

  const _WeeklyProgressCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final week = ProgressHistory.thisWeek();
    final todayIndex = DateTime.now().weekday - 1;
    final recorded = week.whereType<double>().toList();
    final average = recorded.isEmpty ? 0.0 : recorded.reduce((a, b) => a + b) / recorded.length;
    final best = recorded.isEmpty ? -1 : week.indexOf(recorded.reduce((a, b) => a > b ? a : b));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('This week', style: textTheme.titleMedium?.copyWith(fontSize: 16))),
              GlassPill(text: '${(average * 100).round()}% average', color: AppColors.accentOn(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            recorded.isEmpty
                ? 'Your week fills in as you complete things each day.'
                : best >= 0 && week[best]! > 0
                    ? 'Best day so far: ${dayNames[best]}'
                    : 'Complete something today to start your week.',
            style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final v = week[i];
                final isToday = i == todayIndex;
                return Expanded(
                  child: Semantics(
                    label: '${dayNames[i]}: ${v == null ? 'no data' : '${(v * 100).round()} percent'}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (v != null)
                          Text('${(v * 100).round()}', style: textTheme.bodyMedium?.copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Container(
                          width: 18,
                          height: 58,
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECF8),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: (v ?? 0).clamp(0.0, 1.0)),
                            duration: Duration(milliseconds: 700 + i * 80),
                            curve: Curves.easeOutCubic,
                            builder: (context, h, _) => Container(
                              width: 18,
                              height: 58 * h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isToday ? const [AppColors.pink, AppColors.accent] : const [AppColors.sky, AppColors.royal],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday ? AppColors.accentOn(context) : textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
