import '../../services/app_events.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../services/hive_service.dart';
import '../../theme/app_colors.dart';
import '../liquid/liquid.dart';

class WaterTrackerCard extends StatefulWidget {
  final bool onLiquid;

  const WaterTrackerCard({super.key, this.onLiquid = false});

  @override
  State<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends State<WaterTrackerCard> {
  int _currentGlasses = 5;
  final int _goalGlasses = 8;

  @override
  void initState() {
    super.initState();
    lifeDataVersion.addListener(_reload);
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

  void _reload() {
    if (mounted) setState(() => _currentGlasses = Hive.box(HiveService.settingsBox).get('${HiveService.getCurrentUser()}_waterIntake', defaultValue: 0));
  }

  @override
  void dispose() {
    lifeDataVersion.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentGlasses / _goalGlasses;
    final onLiquid = widget.onLiquid;
    final fill = onLiquid ? Colors.white : AppColors.sky;
    final empty = onLiquid ? Colors.white.withValues(alpha: 0.35) : AppColors.lavender.withValues(alpha: 0.5);

    return GlassCard(
      onLiquid: onLiquid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: Text('Water Tracker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              GlassPill(text: '$_currentGlasses / $_goalGlasses glasses', onLiquid: onLiquid, color: AppColors.sky),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_goalGlasses, (index) {
              final isFilled = index < _currentGlasses;
              return Pressable(
                pressedScale: 0.8,
                onTap: () => _updateWater(isFilled && index + 1 == _currentGlasses ? index : index + 1),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: isFilled ? 1 : 0),
                  duration: Duration(milliseconds: 250 + index * 40),
                  curve: Curves.easeOutBack,
                  builder: (context, v, _) => Transform.scale(
                    scale: 0.85 + 0.15 * v,
                    child: Icon(Icons.water_drop_rounded, size: 28, color: Color.lerp(empty, fill, v.clamp(0.0, 1.0))),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(height: 7, decoration: BoxDecoration(color: empty.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(7))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 7,
                  width: c.maxWidth * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: onLiquid ? [AppColors.pink, Colors.white] : [AppColors.sky, AppColors.royal]),
                    borderRadius: BorderRadius.circular(7),
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
