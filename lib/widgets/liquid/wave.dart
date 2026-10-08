import 'dart:math' as math;
import 'package:flutter/material.dart';

enum WaveEdge { top, bottom }

/// Clips a wavy edge with a soft hump in the middle, like the
/// liquid sheet in the reference design. [phase] makes it ripple.
class WaveClipper extends CustomClipper<Path> {
  final WaveEdge edge;
  final double depth; // how far the hump reaches
  final double ripple; // amplitude of the moving ripple
  final double phase; // 0..1

  const WaveClipper({this.edge = WaveEdge.top, this.depth = 22, this.ripple = 4, this.phase = 0});

  double _offset(double x, double w) {
    final hump = math.exp(-math.pow((x - w / 2) / (w * 0.2), 2));
    final wave = math.sin((x / w * 1.6 + phase) * 2 * math.pi);
    return ripple + depth * (1 - hump) + ripple * wave;
  }

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    const step = 4.0;
    if (edge == WaveEdge.top) {
      path.moveTo(0, _offset(0, w));
      for (double x = step; x <= w; x += step) {
        path.lineTo(x, _offset(x, w));
      }
      path
        ..lineTo(w, _offset(w, w))
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(w, 0);
      for (double x = w; x >= 0; x -= step) {
        // Mirror: edges sit higher, center dips down.
        path.lineTo(x, h - _offset(x, w));
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper old) =>
      old.phase != phase || old.depth != depth || old.ripple != ripple || old.edge != edge;
}

/// Clips [child] with a gently rippling wave edge.
class AnimatedWaveClip extends StatefulWidget {
  final Widget child;
  final WaveEdge edge;
  final double depth;
  final double ripple;
  final Duration period;

  const AnimatedWaveClip({
    super.key,
    required this.child,
    this.edge = WaveEdge.top,
    this.depth = 22,
    this.ripple = 4,
    this.period = const Duration(seconds: 6),
  });

  @override
  State<AnimatedWaveClip> createState() => _AnimatedWaveClipState();
}

class _AnimatedWaveClipState extends State<AnimatedWaveClip> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ClipPath(
        clipper: WaveClipper(edge: widget.edge, depth: widget.depth, ripple: widget.ripple, phase: _controller.value),
        child: child,
      ),
    );
  }
}
