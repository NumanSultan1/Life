/// A smaller step inside a task.
class Subtask {
  final String title;
  final bool done;

  const Subtask(this.title, {this.done = false});

  Map<String, dynamic> toMap() => {'title': title, 'done': done};
  factory Subtask.fromMap(Map map) => Subtask((map['title'] ?? '') as String, done: (map['done'] ?? false) as bool);
}

/// How often a task comes back.
const taskRepeats = {'none': 'Never', 'daily': 'Daily', 'weekdays': 'Weekdays', 'weekly': 'Weekly', 'monthly': 'Monthly'};

class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority; // Low, Medium, High
  final DateTime dueDate; // first (or only) occurrence, with time
  final bool isCompleted; // one-off tasks only

  /// When true, a notification fires at the due time.
  final bool hasReminder;

  /// 'none', 'daily', 'weekdays', 'weekly' or 'monthly'.
  final String repeat;

  /// Days (yyyy-MM-dd) a repeating task was done.
  final List<String> completedDates;
  final List<Subtask> subtasks;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'General',
    this.priority = 'Medium',
    required this.dueDate,
    this.isCompleted = false,
    this.hasReminder = false,
    this.repeat = 'none',
    this.completedDates = const [],
    this.subtasks = const [],
  });

  bool get repeats => repeat != 'none';

  static String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whether a repeating task happens on [day].
  bool occursOn(DateTime day) {
    final d = _date(day);
    final start = _date(dueDate);
    if (d.isBefore(start)) return false;
    switch (repeat) {
      case 'daily':
        return true;
      case 'weekdays':
        return d.weekday <= DateTime.friday;
      case 'weekly':
        return d.weekday == start.weekday;
      case 'monthly':
        return d.day == start.day;
      default:
        return d == start;
    }
  }

  /// Done on [day]: per day for repeating tasks, once for one-off tasks.
  bool isDoneOn(DateTime day) => repeats ? completedDates.contains(dayKey(day)) : isCompleted;

  /// Whether the task belongs on [day]'s list: due that day (or repeats
  /// then), or (for today) overdue and still open. The water task is
  /// always for today.
  bool isForDay(DateTime day) {
    final d = _date(day);
    final today = _date(DateTime.now());
    if (id == 'water_drink_task') return d == today;
    if (repeats) return occursOn(d);
    final due = _date(dueDate);
    if (due == d) return true;
    return d == today && due.isBefore(today) && !isCompleted;
  }

  /// Next time this task is due after [after] (for reminders).
  DateTime? nextDue(DateTime after) {
    if (!repeats) return dueDate.isAfter(after) ? dueDate : null;
    var day = _date(after);
    for (var i = 0; i < 400; i++) {
      final at = DateTime(day.year, day.month, day.day, dueDate.hour, dueDate.minute);
      if (occursOn(day) && at.isAfter(after) && !isDoneOn(day)) return at;
      day = day.add(const Duration(days: 1));
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'hasReminder': hasReminder,
      'repeat': repeat,
      'completedDates': completedDates,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      priority: map['priority'] ?? 'Medium',
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : DateTime.now(),
      isCompleted: map['isCompleted'] ?? false,
      hasReminder: map['hasReminder'] ?? false,
      repeat: map['repeat'] ?? 'none',
      completedDates: List<String>.from((map['completedDates'] as List?) ?? const []),
      subtasks: ((map['subtasks'] as List?) ?? const []).map((s) => Subtask.fromMap(s as Map)).toList(),
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    bool? hasReminder,
    String? repeat,
    List<String>? completedDates,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      hasReminder: hasReminder ?? this.hasReminder,
      repeat: repeat ?? this.repeat,
      completedDates: completedDates ?? this.completedDates,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
