class Goal {
  final String id;
  final String title;
  final String description;
  final double progress; // 0.0 to 1.0
  final DateTime targetDate;
  final String category;

  /// How much [progress] moves each day the user checks in
  /// (1 / number of days chosen when the goal was created).
  final double dailyStep;

  /// Date (yyyy-MM-dd) of the most recent check-in, '' if none.
  final String lastCheckIn;
  final int checkInCount;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.progress = 0.0,
    required this.targetDate,
    this.category = 'Personal',
    this.dailyStep = 0.0025,
    this.lastCheckIn = '',
    this.checkInCount = 0,
  });

  /// Goals saved before day-based tracking have no step: spread what's
  /// left over the days until their target (30 days if it has passed).
  static double _legacyStep(double progress, DateTime targetDate) {
    final daysLeft = targetDate.difference(DateTime.now()).inDays;
    final remaining = (1.0 - progress).clamp(0.01, 1.0);
    return remaining / (daysLeft >= 7 ? daysLeft : 30);
  }

  /// Check-ins still needed to reach 100%.
  int get checkInsLeft => progress >= 1.0 ? 0 : ((1.0 - progress) / dailyStep).ceil();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'progress': progress,
      'targetDate': targetDate.toIso8601String(),
      'category': category,
      'dailyStep': dailyStep,
      'lastCheckIn': lastCheckIn,
      'checkInCount': checkInCount,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    final progress = (map['progress'] as num?)?.toDouble() ?? 0.0;
    final targetDate = map['targetDate'] != null ? DateTime.parse(map['targetDate']) : DateTime.now();
    return Goal(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      progress: progress,
      targetDate: targetDate,
      category: map['category'] ?? 'Personal',
      dailyStep: (map['dailyStep'] as num?)?.toDouble() ?? _legacyStep(progress, targetDate),
      lastCheckIn: map['lastCheckIn'] ?? '',
      checkInCount: map['checkInCount'] ?? 0,
    );
  }

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    double? progress,
    DateTime? targetDate,
    String? category,
    double? dailyStep,
    String? lastCheckIn,
    int? checkInCount,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      dailyStep: dailyStep ?? this.dailyStep,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      checkInCount: checkInCount ?? this.checkInCount,
    );
  }
}
