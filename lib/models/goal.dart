class Goal {
  final String id;
  final String title;
  final String description;
  final double progress; // 0.0 to 1.0
  final DateTime targetDate;
  final String category;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.progress = 0.0,
    required this.targetDate,
    this.category = 'Personal',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'progress': progress,
      'targetDate': targetDate.toIso8601String(),
      'category': category,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null ? DateTime.parse(map['targetDate']) : DateTime.now(),
      category: map['category'] ?? 'Personal',
    );
  }

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    double? progress,
    DateTime? targetDate,
    String? category,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
    );
  }
}
