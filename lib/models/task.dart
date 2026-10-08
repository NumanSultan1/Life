class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority; // Low, Medium, High
  final DateTime dueDate;
  final bool isCompleted;

  /// When true, a notification fires at [dueDate] (date and time).
  final bool hasReminder;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'General',
    this.priority = 'Medium',
    required this.dueDate,
    this.isCompleted = false,
    this.hasReminder = false,
  });

  /// Whether the task belongs on [day]'s list: due that day, or (for
  /// today) overdue and still open. The water task is always for today.
  bool isForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (id == 'water_drink_task') return d == today;
    if (due == d) return true;
    return d == today && due.isBefore(today) && !isCompleted;
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
    );
  }
}