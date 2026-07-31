import 'package:flutter/material.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/tasks_tab.dart';
import 'tabs/habits_tab.dart';
import 'tabs/journal_tab.dart';
import 'tabs/goals_tab.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import '../theme/app_colors.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

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

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: tabs[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: isSmallScreen
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      _buildScrollableNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                      _buildScrollableNavItem(1, Icons.check_box_rounded, 'Tasks'),
                      _buildScrollableNavItem(2, Icons.loop_rounded, 'Habits'),
                      _buildScrollableNavItem(3, Icons.auto_stories_rounded, 'Journal'),
                      _buildScrollableNavItem(4, Icons.flag_rounded, 'Goals'),
                      _buildScrollableNavItem(5, Icons.person_rounded, 'Profile'),
                    ],
                  ),
                )
              : BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: Colors.grey,
                  showUnselectedLabels: true,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                    BottomNavigationBarItem(icon: Icon(Icons.check_box_rounded), label: 'Tasks'),
                    BottomNavigationBarItem(icon: Icon(Icons.loop_rounded), label: 'Habits'),
                    BottomNavigationBarItem(icon: Icon(Icons.auto_stories_rounded), label: 'Journal'),
                    BottomNavigationBarItem(icon: Icon(Icons.flag_rounded), label: 'Goals'),
                    BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildScrollableNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
