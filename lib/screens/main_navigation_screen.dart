import 'package:flutter/material.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/tasks_tab.dart';
import 'tabs/habits_tab.dart';
import 'tabs/journal_tab.dart';
import 'tabs/goals_tab.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/liquid/liquid.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const _items = [
    LiquidNavItem(Icons.space_dashboard_rounded, 'Dashboard'),
    LiquidNavItem(Icons.checklist_rounded, 'Tasks'),
    LiquidNavItem(Icons.loop_rounded, 'Habits'),
    LiquidNavItem(Icons.auto_stories_rounded, 'Journal'),
    LiquidNavItem(Icons.flag_rounded, 'Goals'),
    LiquidNavItem(Icons.person_rounded, 'Profile'),
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
        await showAddTaskSheet(context);
      case 2:
        await showAddHabitSheet(context);
      case 3:
        await showJournalSheet(context);
      case 4:
        await showAddGoalSheet(context);
      default:
        await _showQuickAdd();
    }
    if (mounted) setState(() {});
  }

  Future<void> _showQuickAdd() {
    final options = [
      (Icons.add_task_rounded, 'Task', 'Plan something for today', 1, showAddTaskSheet),
      (Icons.loop_rounded, 'Habit', 'Build a daily streak', 2, showAddHabitSheet),
      (Icons.edit_note_rounded, 'Journal', 'Capture a reflection', 3, showJournalSheet),
      (Icons.flag_rounded, 'Goal', 'Aim for something big', 4, showAddGoalSheet),
    ];
    return showLiquidSheet(
      context: context,
      title: 'Create New',
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
                  final (_, _, _, tab, open) = options[i];
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
      const TasksTab(),
      const HabitsTab(),
      const JournalTab(),
      const GoalsTab(),
      const ProfileScreen(),
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
          child: KeyedSubtree(key: ValueKey(_currentIndex), child: tabs[_currentIndex]),
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
