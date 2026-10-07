import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// A blob of color that drifts around the canvas on a looping path.
class _Blob {
  final Color color;
  final Offset anchor; // 0..1 relative position
  final Offset drift; // 0..1 relative drift amplitude
  final double radius; // relative to the longest side
  final double phase;
  final double speed;

  const _Blob(this.color, this.anchor, this.drift, this.radius, this.phase, [this.speed = 1]);
}

enum LiquidPalette { vivid, ambientLight, ambientDark }

const _vividBlobs = [
  _Blob(Color(0xFFF29AD8), Offset(0.08, 0.42), Offset(0.10, 0.20), 0.48, 0.0),
  _Blob(Color(0xFF5FB2F4), Offset(0.92, 0.12), Offset(0.10, 0.12), 0.50, 1.3, 0.8),
  _Blob(Color(0xFF0B47C8), Offset(0.55, 0.55), Offset(0.22, 0.18), 0.55, 2.4, 1.2),
  _Blob(Color(0xFF07258F), Offset(0.88, 0.88), Offset(0.10, 0.12), 0.50, 3.1),
  _Blob(Color(0xFFE58CCF), Offset(0.70, 0.30), Offset(0.18, 0.15), 0.30, 4.2, 0.7),
  _Blob(Color(0xFF8E6BE6), Offset(0.20, 0.90), Offset(0.15, 0.10), 0.38, 5.0, 1.1),
];

const _ambientLightBlobs = [
  _Blob(Color(0xFFE6E0FF), Offset(0.10, 0.10), Offset(0.10, 0.08), 0.70, 0.0),
  _Blob(Color(0xFFDCEBFF), Offset(0.95, 0.35), Offset(0.08, 0.10), 0.70, 1.7, 0.8),
  _Blob(Color(0xFFFBE3F4), Offset(0.20, 0.85), Offset(0.12, 0.08), 0.65, 3.3, 1.1),
];

const _ambientDarkBlobs = [
  _Blob(Color(0xFF1A2A7A), Offset(0.10, 0.10), Offset(0.10, 0.08), 0.75, 0.0),
  _Blob(Color(0xFF3A2380), Offset(0.95, 0.40), Offset(0.08, 0.10), 0.70, 1.7, 0.8),
  _Blob(Color(0xFF0D3A8F), Offset(0.20, 0.90), Offset(0.12, 0.08), 0.65, 3.3, 1.1),
];

/// Continuously flowing "liquid" mesh gradient, used behind sheets,
/// headers, buttons and the nav bar.
class LiquidBackground extends StatefulWidget {
  final Widget? child;
  final LiquidPalette palette;
  final Duration period;
  final bool animate;

  const LiquidBackground({
    super.key,
    this.child,
    this.palette = LiquidPalette.vivid,
    this.period = const Duration(seconds: 14),
    this.animate = true,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period, value: 0.15);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animate && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LiquidPainter(_controller, widget.palette),
        child: widget.child,
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  final Animation<double> animation;
  final LiquidPalette palette;

  _LiquidPainter(this.animation, this.palette) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final List<Color> base;
    final List<_Blob> blobs;
    switch (palette) {
      case LiquidPalette.vivid:
        base = const [Color(0xFF2F64DB), Color(0xFF0A3BAE)];
        blobs = _vividBlobs;
      case LiquidPalette.ambientLight:
        base = const [AppColors.background, Color(0xFFF0F2FC)];
        blobs = _ambientLightBlobs;
      case LiquidPalette.ambientDark:
        base = const [AppColors.darkBackground, Color(0xFF0A1033)];
        blobs = _ambientDarkBlobs;
    }

    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(colors: base, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect),
    );

    final t = animation.value * 2 * math.pi;
    final longest = math.max(size.width, size.height);
    for (final b in blobs) {
      final center = Offset(
        size.width * (b.anchor.dx + b.drift.dx * math.sin(t * b.speed + b.phase)),
        size.height * (b.anchor.dy + b.drift.dy * math.cos(t * b.speed + b.phase * 1.3)),
      );
      final radius = longest * b.radius;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [b.color.withValues(alpha: 0.9), b.color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) => oldDelegate.palette != palette;
}

/// Soft, slowly drifting page background that follows the theme.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Static: it sits behind every page, so animating it would repaint
    // the whole screen every frame for a barely visible drift.
    return LiquidBackground(
      palette: isDark ? LiquidPalette.ambientDark : LiquidPalette.ambientLight,
      animate: false,
      child: child,
    );
  }
}
