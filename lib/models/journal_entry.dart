class JournalEntry {
  final String id;
  final String title;
  final String content;
  final String mood; // 😄 😊 😐 😔 😭
  final DateTime date;
  final bool isFavorite;
  final bool isArchived;

  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    this.mood = '😊',
    required this.date,
    this.isFavorite = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'date': date.toIso8601String(),
      'isFavorite': isFavorite,
      'isArchived': isArchived,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      mood: map['mood'] ?? '😊',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      isFavorite: map['isFavorite'] ?? false,
      isArchived: map['isArchived'] ?? false,
    );
  }

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    String? mood,
    DateTime? date,
    bool? isFavorite,
    bool? isArchived,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      date: date ?? this.date,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
