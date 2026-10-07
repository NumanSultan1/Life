class StreakUtils {
  static const List<int> _baseMilestones = [3, 7, 15, 30, 90, 180, 270, 365];

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Counts the current consecutive-day streak, ending at today or
  /// yesterday (so the streak doesn't visually "break" until a full day
  /// is actually missed).
  static int calculateStreak(List<String> completedDates) {
    final dateSet = completedDates.toSet();
    final now = DateTime.now();
    DateTime cursor = DateTime(now.year, now.month, now.day);

    if (!dateSet.contains(_fmt(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (dateSet.contains(_fmt(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The next milestone target above the given streak.
  /// After 365 days, milestones continue forever in 1-year steps
  /// (730, 1095, 1460 ...) — it never "ends".
  static int nextMilestone(int streak) {
    for (final m in _baseMilestones) {
      if (streak < m) return m;
    }
    final years = (streak / 365).floor() + 1;
    return 365 * years;
  }

  /// True if this exact streak count IS a milestone (used to trigger
  /// the celebration the moment it's hit).
  static bool isMilestone(int streak) {
    if (_baseMilestones.contains(streak)) return true;
    if (streak > 365 && streak % 365 == 0) return true;
    return false;
  }

  /// Friendly label for a milestone number, e.g. 365 -> "1 year".
  static String milestoneLabel(int days) {
    if (days >= 365) {
      final years = days ~/ 365;
      return years == 1 ? '1 year' : '$years years';
    }
    if (days >= 30 && days % 30 == 0) {
      final months = days ~/ 30;
      return '$months month${months > 1 ? 's' : ''}';
    }
    return '$days day${days > 1 ? 's' : ''}';
  }
}