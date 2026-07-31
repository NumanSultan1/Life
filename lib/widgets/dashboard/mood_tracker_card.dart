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

  @override
  void initState() {
    super.initState();
    final box = Hive.box(HiveService.settingsBox);
    _selectedMood = box.get('moodToday', defaultValue: '😊');
  }

  void _selectMood(String emoji) {
    setState(() {
      _selectedMood = emoji;
    });
    final box = Hive.box(HiveService.settingsBox);
    box.put('moodToday', emoji);
  }

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
