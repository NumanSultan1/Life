class Habit {
  final String id;
  final String title;
  final String frequency;
  final int streak;
  final int longestStreak;
  final bool isCompletedToday;
  final String category;
  final int targetCount;
  final int currentCount;

  Habit({
    required this.id,
    required this.title,
    this.frequency = 'Daily',
    this.streak = 0,
    this.longestStreak = 0,
    this.isCompletedToday = false,
    this.category = 'Health',
    this.targetCount = 1,
    this.currentCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'frequency': frequency,
      'streak': streak,
      'longestStreak': longestStreak,
      'isCompletedToday': isCompletedToday,
      'category': category,
      'targetCount': targetCount,
      'currentCount': currentCount,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      frequency: map['frequency'] ?? 'Daily',
      streak: map['streak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      isCompletedToday: map['isCompletedToday'] ?? false,
      category: map['category'] ?? 'Health',
      targetCount: map['targetCount'] ?? 1,
      currentCount: map['currentCount'] ?? 0,
    );
  }

  Habit copyWith({
    String? id,
    String? title,
    String? frequency,
    int? streak,
    int? longestStreak,
    bool? isCompletedToday,
    String? category,
    int? targetCount,
    int? currentCount,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      frequency: frequency ?? this.frequency,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      category: category ?? this.category,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
    );
  }
}