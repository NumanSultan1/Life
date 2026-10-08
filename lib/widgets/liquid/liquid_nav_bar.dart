import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'liquid_background.dart';
import 'motion.dart';
import 'wave.dart';

class LiquidNavItem {
  final IconData icon;
  final String label;

  const LiquidNavItem(this.icon, this.label);
}

/// Deep-blue bottom bar with a wave hump in the middle holding a
/// glowing liquid "+" button. Items are split evenly around it.
class LiquidNavBar extends StatelessWidget {
  final List<LiquidNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;

  const LiquidNavBar({super.key, required this.items, required this.currentIndex, required this.onTap, required this.onCenterTap});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final half = items.length ~/ 2;

    Widget item(int i) => Expanded(child: _NavIcon(item: items[i], selected: i == currentIndex, onTap: () => onTap(i)));

    return SizedBox(
      height: 92 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 14,
            child: AnimatedWaveClip(
              depth: 18,
              ripple: 2,
              period: const Duration(seconds: 8),
              child: Container(
                decoration: const BoxDecoration(gradient: AppColors.navGradient),
                padding: EdgeInsets.only(top: 22, bottom: bottomInset + 4, left: 8, right: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < half; i++) item(i),
                    const SizedBox(width: 76),
                    for (var i = half; i < items.length; i++) item(i),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 0, child: _CenterButton(onTap: onCenterTap)),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final LiquidNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.18 : 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(item.icon, color: Colors.white.withValues(alpha: selected ? 1 : 0.6), size: 23),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(item.label, maxLines: 1),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: selected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.pink,
                borderRadius: BorderRadius.circular(3),
                boxShadow: selected ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.8), blurRadius: 8)] : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CenterButton({required this.onTap});

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  double _turns = 0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Add',
      button: true,
      child: Pressable(
        pressedScale: 0.88,
        onTap: () {
          setState(() => _turns += 0.25);
          widget.onTap();
        },
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final v = Curves.easeOut.transform(_pulse.value);
                  return Container(
                    width: 58 + 16 * v,
                    height: 58 + 16 * v,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.pink.withValues(alpha: 0.6 * (1 - v)), width: 2),
                    ),
                  );
                },
              ),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                  boxShadow: [
                    BoxShadow(color: AppColors.sky.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 6)),
                    BoxShadow(color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(-4, 2)),
                  ],
                ),
                child: ClipOval(
                  child: LiquidBackground(
                    period: const Duration(seconds: 6),
                    child: Center(
                      child: AnimatedRotation(
                        turns: _turns,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
