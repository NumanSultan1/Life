import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/liquid/liquid.dart';
import '../../widgets/illustrations.dart';
import '../../utils/feedback.dart';
import '../../services/notification_service.dart';
import 'package:intl/intl.dart';

const _taskCategories = {
  'General': Icons.inbox_rounded,
  'Work': Icons.work_rounded,
  'Personal': Icons.person_rounded,
  'Fitness': Icons.fitness_center_rounded,
  'Study': Icons.menu_book_rounded,
};

Color priorityColor(String priority) {
  switch (priority) {
    case 'High':
      return AppColors.danger;
    case 'Medium':
      return AppColors.warning;
    default:
      return AppColors.sky;
  }
}

Future<void> showAddTaskSheet(BuildContext context) {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  String category = 'General';
  String priority = 'Medium';
  // Default to the day picked in Plan's calendar, at the next whole hour.
  final day = Provider.of<TaskProvider>(context, listen: false).selectedDay;
  final nextHour = DateTime.now().hour + 1;
  DateTime date = DateTime(day.year, day.month, day.day);
  TimeOfDay time = TimeOfDay(hour: nextHour.clamp(0, 23), minute: 0);
  bool remind = false;

  return showLiquidSheet(
    context: context,
    title: 'Add Task',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setStateModal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetLabel('Task Title'),
            TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(hintText: 'What needs doing?')),
            const SheetLabel('Description'),
            TextField(controller: descController, decoration: const InputDecoration(hintText: 'Optional details')),
            const SheetLabel('Category'),
            IconChoiceGrid(
              options: _taskCategories,
              selected: category,
              onSelected: (c) => setStateModal(() => category = c),
            ),
            const SizedBox(height: 6),
            Text(category, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SheetLabel('When'),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    icon: Icons.calendar_month_rounded,
                    label: _friendlyDate(date),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 5),
                        helpText: 'Task date',
                      );
                      if (picked != null) setStateModal(() => date = picked);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerField(
                    icon: Icons.schedule_rounded,
                    label: time.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: time, helpText: 'Task time');
                      if (picked != null) setStateModal(() => time = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: remind,
              secondary: Icon(Icons.notifications_active_rounded, color: AppColors.accentOn(context)),
              title: const Text('Remind me', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Get a notification at this time'),
              onChanged: (v) async {
                if (v && !await NotificationService.requestPermission()) {
                  if (context.mounted) showInfoSnackBar(context, 'Notifications are off for Life. Turn them on in your phone settings.');
                  return;
                }
                setStateModal(() => remind = v);
              },
            ),
            const SheetLabel('Priority'),
            Row(
              children: ['Low', 'Medium', 'High'].map((p) {
                final selected = p == priority;
                final color = priorityColor(p);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: p == 'High' ? 0 : 10),
                    child: Pressable(
                      onTap: () => setStateModal(() => priority = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? color : color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))] : null,
                        ),
                        child: Text(p, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            GlowButton(
              label: 'Add Task',
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  final newTask = Task(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    category: category,
                    priority: priority,
                    dueDate: DateTime(date.year, date.month, date.day, time.hour, time.minute),
                    hasReminder: remind,
                  );
                  Provider.of<TaskProvider>(sheetContext, listen: false).addTask(newTask);
                  Navigator.pop(sheetContext);
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

/// Search box and category chips shown in the Plan header for tasks.
class TaskFilters extends StatelessWidget {
  const TaskFilters({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    return Column(
      children: [
        TextField(
          onChanged: provider.setSearchQuery,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Search tasks...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white),
            fillColor: Colors.white.withValues(alpha: 0.18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Colors.white, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Work', 'Personal', 'Fitness', 'Study'].map((cat) {
              final selected = provider.selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Pressable(
                  onTap: () => provider.setCategoryFilter(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                    ),
                    child: Text(cat, style: TextStyle(color: selected ? AppColors.royal : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// The task list as slivers, for the Plan tab's scroll view.
class TasksSliver extends StatelessWidget {
  const TasksSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final tasksList = provider.tasksForSelectedDay;
    final dayLabel = _friendlyDate(provider.selectedDay);

    if (tasksList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 110),
          child: EmptyStateWidget(
            icon: Icons.assignment_turned_in_rounded,
            illustration: IllustrationKind.tasks,
            title: provider.totalCount == 0 ? 'Plan your first task' : 'Nothing planned for ${const {'Today', 'Tomorrow', 'Yesterday'}.contains(dayLabel) ? dayLabel.toLowerCase() : dayLabel}',
            description: provider.totalCount == 0
                ? 'Tasks are one-off things to get done, like "Buy groceries" or "Finish report". Pick a date and time, and get a reminder.'
                : 'Pick another day above, or add a task for this day.',
            buttonText: 'Add a task',
            onButtonPressed: () => showAddTaskSheet(context),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) return const _Hint('Tap the circle when a task is done. Swipe left to delete.');
            final task = tasksList[index - 1];
            return StaggerIn(
              key: ValueKey(task.id),
              index: index,
              child: _TaskCard(task: task, provider: provider),
            );
          },
          childCount: tasksList.length + 1,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final TaskProvider provider;

  const _TaskCard({required this.task, required this.provider});

  void _delete(BuildContext context) {
    provider.deleteTask(task.id);
    showUndoSnackBar(context, 'Task deleted', () => provider.addTask(task));
  }

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(task.priority);
    final secondary = Theme.of(context).textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(task.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(context),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.transparent, AppColors.danger]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        child: GlassCard(
          highlighted: task.isCompleted,
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CheckBubble(checked: task.isCompleted, onTap: () => provider.toggleTaskStatus(task.id)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontSize: 15.5,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            color: task.isCompleted ? secondary : null,
                          ),
                      child: Text(task.title),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GlassPill(text: task.priority, color: color),
                        const SizedBox(width: 8),
                        Icon(_taskCategories[task.category] ?? Icons.label_rounded, size: 14, color: secondary),
                        const SizedBox(width: 4),
                        Text(task.category, style: TextStyle(fontSize: 12, color: secondary, fontWeight: FontWeight.w600)),
                        if (task.id != 'water_drink_task') ...[
                          const SizedBox(width: 10),
                          Icon(task.hasReminder ? Icons.notifications_active_rounded : Icons.schedule_rounded, size: 14, color: task.hasReminder ? AppColors.accentOn(context) : secondary),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat.jm().format(task.dueDate),
                            style: TextStyle(fontSize: 12, color: task.hasReminder ? AppColors.accentOn(context) : secondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        task.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondary,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: secondary),
                tooltip: 'Delete task',
                onPressed: () => _delete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round check that fills with royal blue and pops when ticked.
class _CheckBubble extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const _CheckBubble({required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? AppColors.royal : Colors.transparent,
          border: Border.all(color: checked ? AppColors.royal : AppColors.lavender, width: 2),
          boxShadow: checked ? [BoxShadow(color: AppColors.royal.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: AnimatedScale(
          scale: checked ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

String _friendlyDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(d);
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.fieldBg, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accentOn(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// A week of days to browse tasks by date; the calendar button jumps to
/// any day. Dots mark days that have tasks.
class TaskCalendarStrip extends StatelessWidget {
  const TaskCalendarStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final selected = provider.selectedDay;
    final monday = DateTime(selected.year, selected.month, selected.day).subtract(Duration(days: selected.weekday - 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        Row(
          children: [
            GlassIconButton(icon: Icons.chevron_left_rounded, size: 34, onTap: () => provider.selectDay(selected.subtract(const Duration(days: 7)))),
            Expanded(
              child: Text(DateFormat('MMMM yyyy').format(selected), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (DateTime(selected.year, selected.month, selected.day) != today)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Pressable(
                  onTap: () => provider.selectDay(DateTime.now()),
                  child: const GlassPill(text: 'Today', onLiquid: true),
                ),
              ),
            Tooltip(
              message: 'Pick a date',
              child: GlassIconButton(
                icon: Icons.calendar_month_rounded,
                size: 34,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) provider.selectDay(picked);
                },
              ),
            ),
            const SizedBox(width: 6),
            GlassIconButton(icon: Icons.chevron_right_rounded, size: 34, onTap: () => provider.selectDay(selected.add(const Duration(days: 7)))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (i) {
            final day = monday.add(Duration(days: i));
            final isSelected = day.year == selected.year && day.month == selected.month && day.day == selected.day;
            final isToday = day == today;
            final count = provider.countForDay(day);
            return Expanded(
              child: Semantics(
                button: true,
                selected: isSelected,
                label: DateFormat('EEEE d MMMM').format(day),
                child: Pressable(
                  onTap: () => provider.selectDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: isToday ? 0.9 : 0.35), width: isToday ? 1.5 : 1),
                    ),
                    child: Column(
                      children: [
                        Text(DateFormat('E').format(day).substring(0, 2), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? AppColors.textSecondary : Colors.white70)),
                        const SizedBox(height: 2),
                        Text('${day.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? AppColors.royal : Colors.white)),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: count > 0 ? (isSelected ? AppColors.accent : AppColors.pink) : Colors.transparent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
