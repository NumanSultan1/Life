import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../services/hive_service.dart';
import '../common/custom_card.dart';

class WaterTrackerCard extends StatefulWidget {
  const WaterTrackerCard({super.key});

  @override
  State<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends State<WaterTrackerCard> {
  int _currentGlasses = 5;
  final int _goalGlasses = 8;

  @override
  void initState() {
    super.initState();
    final user = HiveService.getCurrentUser();
    final box = Hive.box(HiveService.settingsBox);
    _currentGlasses = box.get('${user}_waterIntake', defaultValue: 0);
  }

  void _updateWater(int count) {
    final user = HiveService.getCurrentUser();
    setState(() {
      _currentGlasses = count.clamp(0, _goalGlasses);
    });
    final box = Hive.box(HiveService.settingsBox);
    box.put('${user}_waterIntake', _currentGlasses);

    // Synchronize water drink task in TaskProvider
    Provider.of<TaskProvider>(context, listen: false).syncWaterTask(_currentGlasses);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentGlasses / _goalGlasses;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_drink_rounded, color: Color(0xFF0284C7), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Water Tracker',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_currentGlasses / $_goalGlasses Glasses',
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_goalGlasses, (index) {
              final isFilled = index < _currentGlasses;
              return GestureDetector(
                onTap: () => _updateWater(index + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isFilled ? const Color(0xFF0284C7).withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFilled ? const Color(0xFF0284C7) : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 20,
                    color: isFilled ? const Color(0xFF0284C7) : Colors.grey.shade400,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
        ],
      ),
    );
  }
}
