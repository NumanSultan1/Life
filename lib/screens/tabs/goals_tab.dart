import 'package:flutter/material.dart';
import '../../models/goal.dart';
import '../../widgets/common/empty_state.dart';
import '../../services/hive_service.dart';
import 'dart:math' as math;

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  List<Goal> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  void _loadGoals() {
    final user = HiveService.getCurrentUser();
    setState(() {
      _goals = HiveService.getGoals(user);
    });
  }

  Future<void> _updateProgress(Goal goal, double newProgress) async {
    final user = HiveService.getCurrentUser();
    final clampedProgress = double.parse(newProgress.clamp(0.0, 1.0).toStringAsFixed(4));

    final oldProgress = goal.progress;
    final updatedGoal = goal.copyWith(progress: clampedProgress);
    await HiveService.saveGoal(updatedGoal, user);

    // Award 100 XP if the goal has just been completed!
    if (oldProgress < 1.0 && clampedProgress >= 1.0) {
      await HiveService.addXp(100);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal Completed! Earned +100 XP! 🏆')),
        );
      }
    }

    _loadGoals();
  }

  Future<void> _deleteGoal(String id) async {
    final user = HiveService.getCurrentUser();
    await HiveService.deleteGoal(id, user);
    _loadGoals();
  }

  void _showSetProgressDialog(Goal goal) {
    final controller = TextEditingController(text: (goal.progress * 100).toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Progress for "${goal.title}"'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Progress Percentage (0 - 100%)',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text.trim());
                if (val != null) {
                  _updateProgress(goal, val / 100.0);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddGoalModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set New Goal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Goal Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isNotEmpty) {
                      final user = HiveService.getCurrentUser();
                      final newGoal = Goal(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        category: 'Career',
                        targetDate: DateTime.now().add(const Duration(days: 30)),
                        progress: 0.0,
                      );
                      await HiveService.saveGoal(newGoal, user);
                      _loadGoals();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Long-Term Goals',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _goals.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.flag_rounded,
                        title: 'No Goals Set',
                        description: 'Set ambitious targets and track your long-term progress!',
                        buttonText: 'Add Goal',
                        onButtonPressed: _showAddGoalModal,
                      )
                    : ListView.builder(
                        itemCount: _goals.length,
                        itemBuilder: (context, index) {
                          final goal = _goals[index];
                          final percentStr = (goal.progress * 100).toStringAsFixed(2);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          goal.title,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _showSetProgressDialog(goal),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$percentStr%',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEC4899)),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                                            onPressed: () => _deleteGoal(goal.id),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (goal.description.isNotEmpty) ...[
                                    Text(goal.description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    const SizedBox(height: 8),
                                  ],
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: math.min(1.0, goal.progress),
                                      minHeight: 8,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        goal.progress >= 1.0 ? '🎉 Goal Completed!' : 'Click +/- to adjust by 0.25%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: goal.progress >= 1.0 ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEC4899)),
                                            onPressed: () => _updateProgress(goal, goal.progress - 0.0025), // 0.25%
                                            tooltip: '-0.25%',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFEC4899)),
                                            onPressed: () => _updateProgress(goal, goal.progress + 0.0025), // 0.25%
                                            tooltip: '+0.25%',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalModal,
        backgroundColor: const Color(0xFFEC4899),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}
