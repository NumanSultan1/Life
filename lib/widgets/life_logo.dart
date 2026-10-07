import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The "life" wordmark: the "f" is replaced by a running person.
///
/// Pass [animation] (0..1) to play the launch sequence: "l" and "i"
/// drop in, the runner sprints in leaving a trail and hops into place,
/// then the "e" pops.
class LifeLogo extends StatelessWidget {
  final double fontSize;
  final bool onLiquid;
  final Animation<double>? animation;

  const LifeLogo({super.key, this.fontSize = 56, this.onLiquid = false, this.animation});

  static double _seg(double t, double start, double end, [Curve curve = Curves.easeOutBack]) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final anim = animation;
    if (anim == null) return _build(1);
    return AnimatedBuilder(animation: anim, builder: (context, _) => _build(anim.value));
  }

  Widget _build(double t) {
    final textColor = onLiquid ? Colors.white : AppColors.navy;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: textColor,
      height: 1,
      letterSpacing: -fontSize * 0.04,
    );
    final runnerSize = fontSize * 1.02;

    Widget drop(String ch, double start) {
      final v = _seg(t, start, start + 0.3);
      return Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, -fontSize * 0.9 * (1 - v)), child: Text(ch, style: style)),
      );
    }

    // Runner sprints in from the left, then a small squash-and-hop on landing.
    final run = _seg(t, 0.25, 0.62, Curves.easeOutCubic);
    final hop = math.sin(_seg(t, 0.58, 0.75, Curves.linear) * math.pi);
    Widget runner(double lag, double opacity) {
      final p = _seg(t, 0.25 + lag, 0.62 + lag, Curves.easeOutCubic);
      return Opacity(
        opacity: opacity * (p > 0 ? 1 : 0),
        child: Transform.translate(
          offset: Offset(-fontSize * 4 * (1 - p), -fontSize * 0.12 * hop),
          child: Icon(
            Icons.directions_run_rounded,
            size: runnerSize,
            color: AppColors.pink,
            shadows: [Shadow(color: AppColors.navy.withValues(alpha: 0.45), blurRadius: fontSize * 0.12, offset: Offset(0, fontSize * 0.03))],
          ),
        ),
      );
    }

    final e = _seg(t, 0.62, 0.9);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        drop('l', 0.0),
        drop('i', 0.1),
        SizedBox(
          width: runnerSize * 0.9,
          child: Transform.translate(
            offset: Offset(-fontSize * 0.04, -fontSize * 0.1),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Motion trail, fading out once the runner lands.
                if (run < 1) ...[runner(0.08, 0.15), runner(0.04, 0.3)],
                runner(0, 1),
              ],
            ),
          ),
        ),
        Transform.scale(
          scale: e,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: e.clamp(0.0, 1.0), child: Text('e', style: style)),
        ),
      ],
    );
  }
}
