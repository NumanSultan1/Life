import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/hive_service.dart';
import '../../theme/app_colors.dart';
import '../liquid/liquid.dart';

class MoodTrackerCard extends StatefulWidget {
  final bool onLiquid;

  const MoodTrackerCard({super.key, this.onLiquid = false});

  @override
  State<MoodTrackerCard> createState() => _MoodTrackerCardState();
}

class _MoodTrackerCardState extends State<MoodTrackerCard> {
  final List<String> _emojis = ['😄', '😊', '😐', '😔', '😭'];
  String _selectedMood = '😊';

  final Map<String, String> _moodTips = {
    '😄': 'Awesome! Spread this positive energy and conquer your goals today! 🌟🚀',
    '😊': 'A peaceful mind is a powerful tool. Have a wonderfully productive and happy day! ✨',
    '😐': 'Take a deep breath. A steady, calm focus is often the most consistent way to move forward. 🧘‍♂️',
    '😔': 'It is okay to have low-energy days. Rest if you need to, and prioritize self-care today. 🩹❤️',
    '😭': 'You are not alone, and this feeling will pass. Take things one small step at a time. 🫂🌻',
  };

  @override
  void initState() {
    super.initState();
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
  }

  @override
  Widget build(BuildContext context) {
    final tip = _moodTips[_selectedMood] ?? 'Have a beautiful and productive day!';
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
                  Icon(Icons.favorite_rounded, color: onLiquid ? AppColors.pink : AppColors.accent, size: 18),
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
