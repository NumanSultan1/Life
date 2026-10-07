import 'package:flutter/material.dart';

/// Activity choices for habits; the key is stored as the habit category.
const Map<String, IconData> habitActivities = {
  'Health': Icons.favorite_rounded,
  'Fitness': Icons.fitness_center_rounded,
  'Running': Icons.directions_run_rounded,
  'Cycling': Icons.directions_bike_rounded,
  'Sleep': Icons.bedtime_rounded,
  'Water': Icons.water_drop_rounded,
  'Mind': Icons.self_improvement_rounded,
  'Study': Icons.menu_book_rounded,
};

IconData habitIcon(String category) => habitActivities[category] ?? Icons.loop_rounded;
