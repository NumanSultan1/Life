import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/liquid/liquid.dart';
import 'goals_tab.dart';
import 'tasks_tab.dart';

/// Which part of Plan is showing: 0 = tasks, 1 = goals. Shared so the
/// center "+" and links from Home can pick the right one.
final ValueNotifier<int> planSegment = ValueNotifier(0);

/// Tasks (things to do today) and goals (bigger things over weeks)
/// together in one tab.
class PlanTab extends StatelessWidget {
  const PlanTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: planSegment,
      builder: (context, segment, _) {
        final tasks = Provider.of<TaskProvider>(context);
        final goals = Provider.of<GoalProvider>(context);
        final dayTasks = tasks.tasksForSelectedDay;
        final subtitle = segment == 0
            ? '${dayTasks.where((t) => t.isCompleted).length} of ${dayTasks.length} tasks done'
            : '${goals.completedCount} of ${goals.goals.length} goals achieved';

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: LiquidHeader(
                  title: 'Plan',
                  subtitle: subtitle,
                  bottom: Column(
                    children: [
                      _SegmentSwitch(value: segment, onChanged: (v) => planSegment.value = v),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: segment == 0
                            ? const Padding(padding: EdgeInsets.only(top: 14), child: Column(children: [TaskCalendarStrip(), SizedBox(height: 14), TaskFilters()]))
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
              if (segment == 0) const TasksSliver() else const GoalsSliver(),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentSwitch extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _SegmentSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = [('Tasks', Icons.checklist_rounded, 'Today'), ('Goals', Icons.flag_rounded, 'Long-term')];
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
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
              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ),
            Row(
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
                            Icon(labels[i].$2, size: 18, color: value == i ? AppColors.royal : Colors.white),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(labels[i].$1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: value == i ? AppColors.royal : Colors.white)),
                                Text(labels[i].$3, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: value == i ? AppColors.textSecondary : Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
