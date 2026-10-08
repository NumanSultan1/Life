import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/task_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/tasks_tab.dart';
import 'tabs/habits_tab.dart';
import 'tabs/journal_tab.dart';
import 'tabs/goals_tab.dart';
import 'tabs/plan_tab.dart';
import 'statistics_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/liquid/liquid.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime _day = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back on a new day: settle streaks, reset water/mood, refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (now.year == _day.year && now.month == _day.month && now.day == _day.day) return;
    _day = now;
    Provider.of<TaskProvider>(context, listen: false).loadTasks();
    Provider.of<HabitProvider>(context, listen: false).loadHabits();
    Provider.of<GoalProvider>(context, listen: false).loadGoals();
    setState(() {});
  }

  static const _items = [
    LiquidNavItem(Icons.home_rounded, 'Home'),
    LiquidNavItem(Icons.event_note_rounded, 'Plan'),
    LiquidNavItem(Icons.loop_rounded, 'Habits'),
    LiquidNavItem(Icons.auto_stories_rounded, 'Journal'),
  ];

  void _onTabTapped(int index) {
    if (index == 6) {
      // Shortcut to Statistics Screen
      Navigator.push(context, MaterialPageRoute(builder: (context) => const StatisticsScreen()));
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  /// The center "+" adds whatever fits the current tab, or offers a
  /// choice on tabs that don't own a list.
  Future<void> _onCenterTap() async {
    switch (_currentIndex) {
      case 1:
        await (planSegment.value == 0 ? showAddTaskSheet(context) : showAddGoalSheet(context));
      case 2:
        await showAddHabitSheet(context);
      case 3:
        await showJournalSheet(context);
      default:
        await _showQuickAdd();
    }
    if (mounted) setState(() {});
  }

  Future<void> _showQuickAdd() {
    // (icon, title, description, tab, plan segment, opener)
    final options = [
      (Icons.add_task_rounded, 'Task', 'Something to get done today', 1, 0, showAddTaskSheet),
      (Icons.loop_rounded, 'Habit', 'Something to repeat every day', 2, 0, showAddHabitSheet),
      (Icons.flag_rounded, 'Goal', 'Something big to work toward over weeks', 1, 1, showAddGoalSheet),
      (Icons.edit_note_rounded, 'Journal entry', 'Write about your day', 3, 0, showJournalSheet),
    ];
    return showLiquidSheet(
      context: context,
      title: 'What would you like to add?',
      builder: (sheetContext) => Column(
        children: [
          for (var i = 0; i < options.length; i++)
            StaggerIn(
              index: i,
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: 12),
                highlighted: true,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final (_, _, _, tab, segment, open) = options[i];
                  if (tab == 1) planSegment.value = segment;
                  setState(() => _currentIndex = tab);
                  await open(context);
                  if (mounted) setState(() {});
                },
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.royal),
                      child: Icon(options[i].$1, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(options[i].$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(options[i].$3, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      DashboardTab(onNavigateTab: _onTabTapped),
      const PlanTab(),
      const HabitsTab(),
      const JournalTab(),
    ];

    return Scaffold(
      extendBody: true,
      body: AmbientBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          // Keyed by day too, so a new day rebuilds cards that cache values.
          child: KeyedSubtree(key: ValueKey('$_currentIndex-${_day.year}-${_day.month}-${_day.day}'), child: tabs[_currentIndex]),
        ),
      ),
      bottomNavigationBar: LiquidNavBar(
        items: _items,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        onCenterTap: _onCenterTap,
      ),
    );
  }
}
