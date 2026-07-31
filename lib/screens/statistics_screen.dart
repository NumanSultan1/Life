import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/journal_provider.dart';
import '../services/hive_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final habitProvider = Provider.of<HabitProvider>(context);
    final journalProvider = Provider.of<JournalProvider>(context);
    final goals = HiveService.getGoals();

    final taskRate = taskProvider.totalCount == 0
        ? 0
        : ((taskProvider.completedCount / taskProvider.totalCount) * 100).toInt();

    final habitRate = (habitProvider.completionPercentage * 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Analytics & Stats', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B6CFF), Color(0xFF7C4DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Productivity Rate', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('$taskRate%', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${taskProvider.completedCount} of ${taskProvider.totalCount} tasks completed', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Real-Time Activity Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildStatRow('Tasks Completed', '${taskProvider.completedCount}', Icons.check_circle_rounded, const Color(0xFF5B6CFF)),
                    const Divider(height: 24),
                    _buildStatRow('Habit Completion Rate', '$habitRate%', Icons.loop_rounded, const Color(0xFF7C4DFF)),
                    const Divider(height: 24),
                    _buildStatRow('Journal Reflections', '${journalProvider.entries.length}', Icons.auto_stories_rounded, const Color(0xFF4CAF50)),
                    const Divider(height: 24),
                    _buildStatRow('Active Goals', '${goals.length}', Icons.flag_rounded, const Color(0xFFEC4899)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
