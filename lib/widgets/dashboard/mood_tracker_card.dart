import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/hive_service.dart';
import '../common/custom_card.dart';

class MoodTrackerCard extends StatefulWidget {
  const MoodTrackerCard({super.key});

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

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "How are you feeling today?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.mood_rounded, color: Color(0xFF7C4DFF)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _emojis.map((emoji) {
              final isSelected = emoji == _selectedMood;
              return GestureDetector(
                onTap: () => _selectMood(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF7C4DFF).withValues(alpha: 0.15) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C4DFF) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: isSelected ? 30 : 24),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFF7C4DFF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
