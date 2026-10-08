import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Four-segment progress ring with a frosted center that counts up
/// to the percentage, matching the reference dashboard.
class SegmentedRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final String? caption;

  const SegmentedRing({super.key, required this.progress, this.size = 120, this.caption});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v, isDark),
            child: Center(
              child: Container(
                width: size * 0.56,
                height: size * 0.56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDark
                      ? LinearGradient(colors: [AppColors.violet.withValues(alpha: 0.45), AppColors.royal.withValues(alpha: 0.6)])
                      : AppColors.ringCenterGradient,
                  boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(v * 100).round()}%',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: size * 0.15,
                      ),
                    ),
                    if (caption != null)
                      Text(caption!, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: size * 0.07, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final bool isDark;

  _RingPainter(this.value, this.isDark);

  static const _colors = [AppColors.pink, Color(0xFFD7E6FA), AppColors.royal, AppColors.sky];

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke);
    const gap = 0.22; // radians between segments
    const seg = math.pi / 2;
    const start = -math.pi / 2 + gap / 2;

    for (var i = 0; i < 4; i++) {
      final segStart = start + i * seg;
      final sweep = seg - gap;
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = (isDark ? Colors.white : AppColors.lavender).withValues(alpha: isDark ? 0.08 : 0.22);
      canvas.drawArc(rect, segStart, sweep, false, track);

      final filled = ((value * 4) - i).clamp(0.0, 1.0);
      if (filled > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = _colors[i];
        canvas.drawArc(rect, segStart, sweep * filled, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.isDark != isDark;
}
