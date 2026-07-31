import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onAddHabit;
  final VoidCallback onWriteJournal;
  final VoidCallback onStudySession;
  final VoidCallback onAddGoal;
  final VoidCallback onStatistics;

  const QuickActionsGrid({
    super.key,
    required this.onAddTask,
    required this.onAddHabit,
    required this.onWriteJournal,
    required this.onStudySession,
    required this.onAddGoal,
    required this.onStatistics,
  });

  Widget _buildItem(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildItem(context, 'Add Task', Icons.add_task_rounded, const Color(0xFF5B6CFF), onAddTask),
        _buildItem(context, 'Add Habit', Icons.loop_rounded, const Color(0xFF7C4DFF), onAddHabit),
        _buildItem(context, 'Write Journal', Icons.edit_note_rounded, const Color(0xFF4CAF50), onWriteJournal),
        _buildItem(context, 'Study Session', Icons.timer_rounded, const Color(0xFFFF9800), onStudySession),
        _buildItem(context, 'Add Goal', Icons.flag_rounded, const Color(0xFFEC4899), onAddGoal),
        _buildItem(context, 'Statistics', Icons.bar_chart_rounded, const Color(0xFF06B6D4), onStatistics),
      ],
    );
  }
}
