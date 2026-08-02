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

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });
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

      if (currentHour >= 21) { // Past 9:00 PM
        if (waterIntake < 8) {
          waterTitle = 'Finish Strong! ⏰💧';
          waterBody = 'It is past 9:00 PM and you have only drunk $waterIntake of 8 glasses. Let\'s reach your daily goal!';
        } else {
          shouldShowWaterAlert = false;
        }
      } else if (currentHour >= 18) { // Past 6:00 PM
        if (waterIntake < 6) {
          waterTitle = 'Boost Your Focus! ⏰💧';
          waterBody = 'It is past 6:00 PM and you have only drunk $waterIntake of 6 glasses. Hydration keeps you energized!';
        } else {
          shouldShowWaterAlert = false;
        }
      } else if (currentHour >= 15) { // Past 3:00 PM
        if (waterIntake < 4) {
          waterTitle = 'Keep Going! ⏰💧';
          waterBody = 'It is past 3:00 PM and you have only drunk $waterIntake of 4 glasses. A quick glass of water boosts memory!';
        } else {
          shouldShowWaterAlert = false;
        }
      } else if (currentHour >= 12) { // Past 12:00 PM
        if (waterIntake < 2) {
          waterTitle = 'Hydration Alert! ⏰💧';
          waterBody = 'It is past 12:00 PM and you have only drunk $waterIntake of 2 glasses. Take a quick sip to stay sharp!';
        } else {
          shouldShowWaterAlert = false;
        }
      }

      if (shouldShowWaterAlert) {
        items.add(NotificationItem(
          id: 'water_$todayStr',
          title: waterTitle,
          body: waterBody,
          icon: Icons.local_drink_rounded,
          color: Colors.blue,
        ));
      }
    }

    // 2. High Priority Task Notification
    final highPriorityTasks = taskProvider.tasks.where((t) => t.priority == 'High' && !t.isCompleted).toList();
    for (var task in highPriorityTasks) {
      items.add(NotificationItem(
        id: 'task_${task.id}',
        title: 'Urgent Task Pending ⚠️',
        body: 'Do not forget to complete: "${task.title}"',
        icon: Icons.priority_high_rounded,
        color: Colors.red,
      ));
    }

    // 3. Habit Completion Notification
    final uncompletedHabits = habitProvider.habits.where((h) => !h.isCompletedToday).toList();
    for (var habit in uncompletedHabits) {
      items.add(NotificationItem(
        id: 'habit_${habit.id}_$todayStr',
        title: 'Maintain Your Streak! 🔥',
        body: 'You haven\'t completed your "${habit.title}" habit today.',
        icon: Icons.local_fire_department_rounded,
        color: Colors.orange,
      ));
    }

    // 4. Level Up Notification
    final currentLvl = box.get('${user}_level', defaultValue: 1) as int;
    if (currentLvl > 1) {
      items.add(NotificationItem(
        id: 'level_$currentLvl',
        title: 'Level $currentLvl Unlocked! 🎉',
        body: 'Congratulations on reaching Level $currentLvl! Keep up the amazing work.',
        icon: Icons.emoji_events_rounded,
        color: Colors.amber,
      ));
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final list = _getDynamicNotifications();
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications Center 🔔',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (list.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _dismissAllNotifications(list);
                            setStateSheet(() {});
                            setState(() {}); // refresh parent
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All notifications cleared')),
                            );
                          },
                          child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'All caught up!',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'No new alerts or suggestions at this time.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item.color.withValues(alpha: 0.12),
                                child: Icon(item.icon, color: item.color),
                              ),
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(item.body, style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () {
                                  _dismissNotification(item.id);
                                  setStateSheet(() {});
                                  setState(() {}); // refresh parent
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData(); // Ensure live level/xp is shown on rebuild
    final taskProvider = Provider.of<TaskProvider>(context);
    final habitProvider = Provider.of<HabitProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayFormatted = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    final notificationList = _getDynamicNotifications();
    final unreadCount = notificationList.length;

    final xpNeeded = _level * 100;
    final xpProgress = _xp / xpNeeded;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Greeting Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Morning, $_userName 👋',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todayFormatted,
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showNotificationsBottomSheet(context),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_rounded, size: 28),
                        if (unreadCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gamified XP & Level bar on Dashboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Level $_level Hero',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '$_xp / $xpNeeded XP',
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: xpProgress,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Overview Metrics Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B6CFF), Color(0xFF7C4DFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B6CFF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TODAY'S OVERVIEW",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Tasks', '${taskProvider.completedCount}/${taskProvider.totalCount}', Icons.check_circle_rounded),
                    _buildMetric('Habits', '${habitProvider.completedTodayCount}/${habitProvider.totalHabits}', Icons.loop_rounded),
                    _buildMetric('Streak', '${habitProvider.habits.fold(0, (max, h) => h.streak > max ? h.streak : max)} Days', Icons.local_fire_department_rounded),
                    _buildMetric('Mood', Hive.box(HiveService.settingsBox).get('${_userName}_moodToday', defaultValue: '😊'), Icons.mood_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Interactive Cards: Mood Tracker & Water Tracker
          const MoodTrackerCard(),
          const SizedBox(height: 16),
          const WaterTrackerCard(),
          const SizedBox(height: 24),

          // Quick Actions Grid
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _buildActionCard(context, 'Add Task', Icons.add_task_rounded, const Color(0xFF5B6CFF), () => widget.onNavigateTab(1)),
              _buildActionCard(context, 'Add Habit', Icons.loop_rounded, const Color(0xFF7C4DFF), () => widget.onNavigateTab(2)),
              _buildActionCard(context, 'Journal', Icons.edit_note_rounded, const Color(0xFF4CAF50), () => widget.onNavigateTab(3)),
              _buildActionCard(context, 'Goals', Icons.flag_rounded, const Color(0xFFEC4899), () => widget.onNavigateTab(4)),
              _buildActionCard(context, 'Statistics', Icons.bar_chart_rounded, const Color(0xFF06B6D4), () => widget.onNavigateTab(5)),
              _buildActionCard(context, 'Profile', Icons.person_rounded, const Color(0xFFFF9800), () => widget.onNavigateTab(5)),
            ],
          ),
          const SizedBox(height: 24),

          // Today's Tasks Brief
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Tasks",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(1),
                child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (taskProvider.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No tasks created yet. Tap + to add one!', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...taskProvider.tasks.take(3).map((task) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (_) => taskProvider.toggleTaskStatus(task.id),
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              color: task.isCompleted ? Colors.grey : null,
                            ),
                          ),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              task.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.priority,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          const MotivationalQuoteCard(),
        ],
      ),
    );
  }

  static Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  static Widget _buildActionCard(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
