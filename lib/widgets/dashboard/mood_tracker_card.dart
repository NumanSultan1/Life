import '../../services/app_events.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/hive_service.dart';
import '../../theme/app_colors.dart';
import '../liquid/liquid.dart';
import '../../data/daily_quotes.dart';

class MoodTrackerCard extends StatefulWidget {
  final bool onLiquid;

  const MoodTrackerCard({super.key, this.onLiquid = false});

  @override
  State<MoodTrackerCard> createState() => _MoodTrackerCardState();
}

class _MoodTrackerCardState extends State<MoodTrackerCard> {
  final List<String> _emojis = ['😄', '😊', '😐', '😔', '😭'];
  String _selectedMood = '😊';

  @override
  void initState() {
    super.initState();
    lifeDataVersion.addListener(_reload);
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    _selectedMood = box.get('${user}_moodToday', defaultValue: '😊');
  }

  void _selectMood(String emoji) {
    final user = HiveService.getCurrentUser();
    setState(() {
      _selectedMood = emoji;
    });
    final box = Hive.box(HiveService.settingsBox);
    box.put('${user}_moodToday', emoji);
    // Keep a daily history for Insights and the weekly review.
    final log = Map<String, dynamic>.from(box.get('${user}_moodLog', defaultValue: <String, dynamic>{}) as Map);
    log[DateFormat('yyyy-MM-dd').format(DateTime.now())] = emoji;
    box.put('${user}_moodLog', log);
  }

  void _reload() {
    if (mounted) setState(() => _selectedMood = Hive.box(HiveService.settingsBox).get('${HiveService.getCurrentUser()}_moodToday', defaultValue: '😊'));
  }

  @override
  void dispose() {
    lifeDataVersion.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = quoteForMood(_selectedMood);
    final onLiquid = widget.onLiquid;
    final ring = onLiquid ? Colors.white : AppColors.royal;

    return GlassCard(
      onLiquid: onLiquid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: Text('How are you feeling today?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Icon(Icons.mood_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _emojis.map((emoji) {
              final isSelected = emoji == _selectedMood;
              return Pressable(
                onTap: () => _selectMood(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? ring.withValues(alpha: onLiquid ? 0.28 : 0.1) : Colors.transparent,
                    border: Border.all(color: isSelected ? ring : Colors.transparent, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: isSelected ? 1.25 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_selectedMood),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: onLiquid ? Colors.white.withValues(alpha: 0.14) : AppColors.lavender.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.format_quote_rounded, color: onLiquid ? AppColors.pink : AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
