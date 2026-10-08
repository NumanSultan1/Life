import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Letter gradient (blue → violet) and the runner's contrasting pink.
const _letterColors = [Color(0xFF3F8CFF), Color(0xFF5B5BF0), Color(0xFF8B3FE8)];
const _runnerColors = [Color(0xFFFF8FC2), Color(0xFFF0509A)];

/// The "Life" wordmark: a sprinting athlete stands in for the "f".
///
/// Pass [animation] (0..1) to play the launch sequence: "L" and "i"
/// drop in, the runner sprints in with speed lines and lands in
/// place, then the "e" pops.
class LifeLogo extends StatelessWidget {
  final double fontSize;
  final Animation<double>? animation;

  const LifeLogo({super.key, this.fontSize = 56, this.animation});

  static double _seg(double t, double start, double end, [Curve curve = Curves.easeOutBack]) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final anim = animation;
    if (anim == null) return _build(1);
    return AnimatedBuilder(animation: anim, builder: (context, _) => _build(anim.value));
  }

  Widget _letters(String text, double opacity, Offset offset, double scale) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: offset,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: _letterColors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(r),
            child: Text(
              text,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: Colors.white, height: 1, letterSpacing: -fontSize * 0.02),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build(double t) {
    final l = _seg(t, 0.0, 0.3);
    final i = _seg(t, 0.1, 0.4);
    final run = _seg(t, 0.25, 0.65, Curves.easeOutCubic);
    final land = math.sin(_seg(t, 0.6, 0.78, Curves.linear) * math.pi);
    final e = _seg(t, 0.62, 0.9);
    final runnerW = fontSize * 1.3;
    final runnerH = fontSize * 1.56;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _letters('L', l, Offset(0, -fontSize * (1 - l)), 1),
        _letters('i', i, Offset(0, -fontSize * (1 - i)), 1),
        SizedBox(
          width: runnerW * 0.8,
          height: fontSize,
          child: OverflowBox(
            maxWidth: runnerW,
            maxHeight: runnerH,
            alignment: const Alignment(0.55, 0.62),
            child: Opacity(
              opacity: run > 0 ? 1 : 0,
              child: Transform.translate(
                offset: Offset(-fontSize * 4 * (1 - run), -fontSize * 0.08 * land),
                child: CustomPaint(size: Size(runnerW, runnerH), painter: _RunnerPainter(speed: 1 - run * 0.6)),
              ),
            ),
          ),
        ),
        _letters('e', e, Offset.zero, e),
      ],
    );
  }
}

/// A forward-leaning sprinter drawn from tapered limbs, with speed
/// lines behind. Drawn on a 100 x 120 grid, facing right.
class _RunnerPainter extends CustomPainter {
  final double speed; // 0..1 strength of the speed lines
  final Color? color; // solid colour instead of the brand gradient
  final bool speedLines;

  _RunnerPainter({this.speed = 0.4, this.color, this.speedLines = true});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 120);
    final paint = Paint();
    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = const LinearGradient(colors: _runnerColors, begin: Alignment.topRight, end: Alignment.bottomLeft).createShader(const Rect.fromLTWH(0, 0, 100, 120));
    }
    // Each part is drawn on its own so overlapping shapes never cancel out.
    final body = _Painting(canvas, paint);

    void limb(Offset a, Offset b, double wa, double wb) {
      final d = b - a;
      final n = Offset(-d.dy, d.dx) / d.distance;
      body
        ..addPolygon([a + n * wa / 2, b + n * wb / 2, b - n * wb / 2, a - n * wa / 2], true)
        ..addOval(Rect.fromCircle(center: a, radius: wa / 2))
        ..addOval(Rect.fromCircle(center: b, radius: wb / 2));
    }

    // Head and neck.
    body.addOval(Rect.fromCircle(center: const Offset(69, 13), radius: 10));
    limb(const Offset(65, 20), const Offset(60, 29), 11, 13);
    // Back arm swinging behind (drawn first so the torso overlaps it).
    limb(const Offset(54, 32), const Offset(40, 46), 13, 10);
    limb(const Offset(40, 46), const Offset(27, 39), 10, 7.5);
    body.addOval(Rect.fromCircle(center: const Offset(26, 37), radius: 4.6));
    // Back leg: pushing off, fully extended.
    limb(const Offset(42, 62), const Offset(31, 88), 17, 11);
    limb(const Offset(31, 88), const Offset(15, 108), 11, 6);
    limb(const Offset(15, 108), const Offset(7, 113), 6, 4.5);
    // Torso: broad chest tapering to the waist, leaning forward.
    limb(const Offset(58, 31), const Offset(43, 61), 22, 15);
    body.addOval(Rect.fromCircle(center: const Offset(43, 61), radius: 9));
    // Front leg: knee driven high, shin tucked back.
    limb(const Offset(45, 60), const Offset(67, 71), 18, 12);
    limb(const Offset(67, 71), const Offset(58, 96), 12, 7);
    limb(const Offset(58, 96), const Offset(70, 99), 7, 5);
    // Front arm driving forward and up.
    limb(const Offset(61, 32), const Offset(76, 46), 13, 10);
    limb(const Offset(76, 46), const Offset(86, 31), 10, 7.5);
    body.addOval(Rect.fromCircle(center: const Offset(87, 28), radius: 4.6));

    if (!speedLines) return;
    // Speed lines trailing behind.
    final lines = Paint()
      ..color = _runnerColors.last.withValues(alpha: 0.35 + 0.5 * speed)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      // Trail off the front foot, under the body like the reference.
      final y = 100.0 + k * 6;
      final x = 50.0 - k * 6;
      final len = (18 - k * 4) * (0.7 + speed);
      canvas.drawLine(Offset(x - len, y + len * 0.35), Offset(x, y), lines);
    }
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter old) => old.speed != speed || old.color != color;
}

/// Minimal Path-like facade that paints each shape as soon as it's added.
class _Painting {
  final Canvas canvas;
  final Paint paint;

  _Painting(this.canvas, this.paint);

  void addOval(Rect r) => canvas.drawOval(r, paint);
  void addPolygon(List<Offset> points, bool close) => canvas.drawPath(Path()..addPolygon(points, close), paint);
}

/// The logo on a white rounded tile, matching the app icon, for use on
/// coloured backgrounds.
class LifeLogoBadge extends StatelessWidget {
  final double fontSize;

  const LifeLogoBadge({super.key, this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(fontSize * 0.55, fontSize * 0.45, fontSize * 0.55, fontSize * 0.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF1EFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(fontSize * 0.55),
        boxShadow: [BoxShadow(color: const Color(0xFF051F82).withValues(alpha: 0.25), blurRadius: fontSize * 0.6, offset: Offset(0, fontSize * 0.2))],
      ),
      child: LifeLogo(fontSize: fontSize),
    );
  }
}

/// Just the runner from the logo, e.g. for the notification icon.
class RunnerMark extends StatelessWidget {
  final double height;
  final Color? color;
  final bool speedLines;

  const RunnerMark({super.key, this.height = 48, this.color, this.speedLines = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(height * 100 / 120, height), painter: _RunnerPainter(color: color, speedLines: speedLines));
  }
}
