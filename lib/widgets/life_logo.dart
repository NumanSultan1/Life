import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Sky blue → purple, shared by the letters and the runner.
const _logoColors = [Color(0xFF38A6F7), Color(0xFF5A6CF0), Color(0xFF7B3AE6)];

const _letterStyleBase = TextStyle(
  fontFamily: 'NunitoLogo',
  fontVariations: [FontVariation('wght', 860)],
  color: Colors.white,
  height: 1,
);

/// The "Life" wordmark: rounded "L", "i" and "e" with a sprinting athlete
/// as the "f" — his back fist is the dot of the "i".
///
/// Pass [animation] (0..1) to play the launch sequence: "L" and "i" drop
/// in, the runner sprints in with speed lines, then the "e" pops.
class LifeLogo extends StatelessWidget {
  final double fontSize;
  final Animation<double>? animation;

  const LifeLogo({super.key, this.fontSize = 56, this.animation});

  @override
  Widget build(BuildContext context) {
    final layout = _LogoLayout(fontSize);
    final anim = animation;
    Widget paint(double t) => CustomPaint(size: layout.size, painter: _LogoPainter(layout, t));
    return Semantics(
      label: 'Life',
      child: anim == null ? paint(1) : AnimatedBuilder(animation: anim, builder: (context, _) => paint(anim.value)),
    );
  }
}

/// Measures the letters once and places the runner relative to them.
class _LogoLayout {
  final double fs;
  late final TextPainter l, i, e;
  late final double baseline, xI, xE, runnerX, runnerY, scale;
  late final Size size;

  _LogoLayout(this.fs) {
    TextPainter tp(String s) => TextPainter(text: TextSpan(text: s, style: _letterStyleBase.copyWith(fontSize: fs)), textDirection: TextDirection.ltr)..layout();
    l = tp('L');
    i = tp('ı'); // dotless i: the runner's fist is the dot
    e = tp('e');
    scale = 1.5 * fs / 112;

    final ascent = l.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    xI = l.width - fs * 0.03;
    final stemCenter = xI + i.width / 2;
    // Fist (runner grid 16.4, 27.2) sits above the stem like an i-dot.
    final fistRel = -0.72 * fs; // relative to the baseline
    runnerX = stemCenter - 16.4 * scale;
    final runnerTopRel = fistRel - 27.2 * scale;
    final top = math.min(runnerTopRel, -ascent);
    baseline = -top;
    runnerY = baseline + runnerTopRel;
    xE = runnerX + 71 * scale;
    final bottom = math.max(runnerY + 112 * scale, baseline + fs * 0.25);
    size = Size(xE + e.width, bottom);
  }
}

class _LogoPainter extends CustomPainter {
  final _LogoLayout layout;
  final double t;

  _LogoPainter(this.layout, this.t);

  static double _seg(double t, double start, double end, [Curve curve = Curves.easeOutBack]) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final fs = layout.fs;
    final shader = const LinearGradient(colors: _logoColors, begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Offset.zero & size);

    void letter(TextPainter tp, double x, double opacity, Offset offset, double scale) {
      if (opacity <= 0) return;
      final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final origin = Offset(x, layout.baseline - ascent) + offset;
      canvas.save();
      if (scale != 1) {
        final pivot = Offset(x + tp.width / 2, layout.baseline);
        canvas.translate(pivot.dx, pivot.dy);
        canvas.scale(scale);
        canvas.translate(-pivot.dx, -pivot.dy);
      }
      // Paint the glyph as a mask, then fill it with the shared gradient.
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)));
      tp.paint(canvas, origin);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.srcIn,
      );
      canvas.restore();
      canvas.restore();
    }

    final l = _seg(t, 0.0, 0.3);
    final i = _seg(t, 0.1, 0.4);
    final run = _seg(t, 0.25, 0.65, Curves.easeOutCubic);
    final hop = math.sin(_seg(t, 0.6, 0.78, Curves.linear) * math.pi);
    final e = _seg(t, 0.62, 0.9);

    letter(layout.l, 0, l, Offset(0, -fs * (1 - l)), 1);
    letter(layout.i, layout.xI, i, Offset(0, -fs * (1 - i)), 1);
    letter(layout.e, layout.xE, e, Offset.zero, e);

    if (run <= 0) return;
    canvas.save();
    canvas.translate(layout.runnerX - fs * 4 * (1 - run), layout.runnerY - fs * 0.08 * hop);
    canvas.scale(layout.scale);
    final body = runnerPath();
    // White halo carves a gap where the runner crosses the letters.
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeJoin = StrokeJoin.round,
    );
    final runnerShader = const LinearGradient(colors: _logoColors, begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(const Rect.fromLTWH(0, 0, 100, 112));
    canvas.drawPath(body, Paint()..shader = runnerShader);
    _speedLines(canvas, runnerShader, 1 - run * 0.5);
    canvas.restore();
  }

  void _speedLines(Canvas canvas, Shader shader, double strength) {
    // White slits across the back arm, like motion blur.
    final slit = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(30, 25.2), const Offset(42, 24.4), slit);
    canvas.drawLine(const Offset(33, 28.6), const Offset(44, 28.0), slit);
    // Trailing lines behind the front foot.
    final trail = Paint()
      ..shader = shader
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final y = 89.0 + k * 4.2;
      final x = 39.0 - k * 2.5;
      final len = (13 - k * 3) * (0.8 + strength * 0.4);
      canvas.drawLine(Offset(x - len, y + len * 0.42), Offset(x, y), trail);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.t != t || old.layout != layout;
}

/// A muscular sprinter on a 100 x 112 grid, facing right, built from
/// tapered limbs with muscle bulges and merged into one silhouette.
Path runnerPath() {
  Path limb(Offset a, Offset b, double wa, double wb, {double bulgeA = 0, double bulgeB = 0}) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final mid = a + d * 0.45;
    final wm = (wa + wb) / 2;
    final a1 = a + n * wa / 2, b1 = b + n * wb / 2, b2 = b - n * wb / 2, a2 = a - n * wa / 2;
    final c1 = mid + n * (wm / 2 + bulgeA), c2 = mid - n * (wm / 2 + bulgeB);
    // Tapered body with a muscle bulge on each side, plus round joints
    // (separate circles, so the union never leaves gaps at the ends).
    final shape = Path()
      ..moveTo(a1.dx, a1.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, b1.dx, b1.dy)
      ..lineTo(b2.dx, b2.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, a2.dx, a2.dy)
      ..close();
    return Path.combine(
      ui.PathOperation.union,
      shape,
      Path()
        ..addOval(Rect.fromCircle(center: a, radius: wa / 2))
        ..addOval(Rect.fromCircle(center: b, radius: wb / 2)),
    );
  }

  Path oval(Offset c, double rx, double ry, [double angle = 0]) {
    final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2));
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(angle);
    return p.transform(m.storage);
  }

  /// Smooth closed outline through [pts] (Catmull-Rom).
  Path smooth(List<Offset> pts) {
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var k = 0; k < pts.length; k++) {
      final p0 = pts[(k - 1 + pts.length) % pts.length];
      final p1 = pts[k];
      final p2 = pts[(k + 1) % pts.length];
      final p3 = pts[(k + 2) % pts.length];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return p..close();
  }

  final parts = <Path>[
    // Head, slightly forward with a jaw line.
    oval(const Offset(75.5, 9.8), 8.2, 9.4, 0.25),
    oval(const Offset(79.5, 14.2), 3.6, 3.0, 0.3),
    limb(const Offset(72, 15), const Offset(67, 23), 8, 10),
    // Torso: broad shoulders and chest, tapering to the waist.
    smooth(const [
      Offset(49, 19.5),
      Offset(58, 15.8),
      Offset(68, 19.5),
      Offset(73, 27),
      Offset(71.5, 35),
      Offset(64, 46),
      Offset(61.5, 55),
      Offset(52, 61),
      Offset(44.5, 58),
      Offset(46.5, 47),
      Offset(46, 33),
    ]),
    // Back arm reaching back; the fist is the dot of the "i".
    limb(const Offset(52, 22), const Offset(33, 25.5), 10.5, 8, bulgeA: 1.6),
    limb(const Offset(33, 25.5), const Offset(20, 27), 8, 6.5, bulgeB: 0.8),
    oval(const Offset(16.4, 27.2), 7.2, 6.8),
    // Front arm driving up.
    limb(const Offset(66, 26), const Offset(82, 37), 10.5, 7.5, bulgeB: 1.8),
    limb(const Offset(82, 37), const Offset(92, 22.5), 7.5, 5.5, bulgeA: 1.2),
    oval(const Offset(93.6, 19.6), 4.0, 4.6, -0.4),
    // Glutes and front leg: knee high, shin tucked back, toes down.
    oval(const Offset(49.5, 57), 8.5, 7.5, 0.4),
    limb(const Offset(55, 52), const Offset(73.5, 59.5), 17.5, 10.5, bulgeA: 2.6),
    limb(const Offset(73.5, 59.5), const Offset(51.5, 84), 10, 5, bulgeB: 3.2),
    limb(const Offset(51.5, 84), const Offset(44, 93.5), 5.2, 3.6),
    limb(const Offset(52.5, 84.5), const Offset(54, 88), 3.6, 3),
    // Back leg pushing off, fully extended.
    limb(const Offset(48, 57), const Offset(30, 78.5), 17, 10, bulgeB: 2.4),
    limb(const Offset(30, 78.5), const Offset(9.5, 101.5), 9.6, 4.8, bulgeA: 3.0),
    limb(const Offset(9.5, 101.5), const Offset(2.5, 110), 4.8, 3.2),
  ];

  var body = parts.first;
  for (final p in parts.skip(1)) {
    body = Path.combine(ui.PathOperation.union, body, p);
  }
  return body;
}

/// The logo on a white rounded tile, matching the app icon, for use on
/// coloured backgrounds.
class LifeLogoBadge extends StatelessWidget {
  final double fontSize;

  const LifeLogoBadge({super.key, this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(fontSize * 0.5, fontSize * 0.3, fontSize * 0.5, fontSize * 0.25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF1EFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(fontSize * 0.55),
        boxShadow: [BoxShadow(color: const Color(0xFF051F82).withValues(alpha: 0.25), blurRadius: fontSize * 0.6, offset: Offset(0, fontSize * 0.2))],
      ),
      child: LifeLogo(fontSize: fontSize),
    );
  }
}

/// Just the runner, e.g. for the notification icon.
class RunnerMark extends StatelessWidget {
  final double height;
  final Color color;

  const RunnerMark({super.key, this.height = 48, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(height * 100 / 112, height), painter: _RunnerMarkPainter(color));
}

class _RunnerMarkPainter extends CustomPainter {
  final Color color;

  _RunnerMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 112);
    canvas.drawPath(runnerPath(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RunnerMarkPainter old) => old.color != color;
}
