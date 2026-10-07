import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Small animated scenes drawn in code, used for onboarding, empty
/// states and the home screen. Each loops gently and holds still when
/// the system "reduce motion" setting is on.
enum IllustrationKind { welcome, tasks, habits, goals, journal, allDone, stats }

class Illustration extends StatefulWidget {
  final IllustrationKind kind;
  final double size;

  const Illustration(this.kind, {super.key, this.size = 180});

  @override
  State<Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<Illustration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4), value: 0.6);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _ScenePainter(widget.kind, _controller, isDark)),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final IllustrationKind kind;
  final Animation<double> anim;
  final bool isDark;

  _ScenePainter(this.kind, this.anim, this.isDark) : super(repaint: anim);

  double get t => anim.value;
  double wave([double phase = 0, double speed = 1]) => math.sin((t * speed + phase) * 2 * math.pi);

  Color get paper => isDark ? const Color(0xFF1C2556) : Colors.white;
  Color get line => isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFDDE2F5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    _backdrop(canvas);
    switch (kind) {
      case IllustrationKind.welcome:
        _welcome(canvas);
      case IllustrationKind.tasks:
        _tasks(canvas);
      case IllustrationKind.habits:
        _habits(canvas);
      case IllustrationKind.goals:
        _goals(canvas);
      case IllustrationKind.journal:
        _journal(canvas);
      case IllustrationKind.allDone:
        _allDone(canvas);
      case IllustrationKind.stats:
        _stats(canvas);
    }
    _sparkles(canvas);
  }

  // --- Shared pieces (all coordinates are on a 200x200 canvas) ---

  void _backdrop(Canvas canvas) {
    const c = Offset(100, 108);
    canvas.drawCircle(
      c,
      82,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.lavender.withValues(alpha: isDark ? 0.35 : 0.45),
          AppColors.pink.withValues(alpha: isDark ? 0.15 : 0.25),
          AppColors.sky.withValues(alpha: 0),
        ], stops: const [0, 0.6, 1]).createShader(Rect.fromCircle(center: c, radius: 82)),
    );
  }

  void _sparkles(Canvas canvas) {
    const spots = [Offset(30, 40), Offset(172, 56), Offset(160, 168), Offset(40, 160)];
    for (var i = 0; i < spots.length; i++) {
      final s = (wave(i * 0.25) + 1) / 2;
      _star(canvas, spots[i], 3 + 3 * s, (i.isEven ? AppColors.pink : AppColors.sky).withValues(alpha: 0.4 + 0.5 * s));
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.35;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  void _card(Canvas canvas, RRect r, {Color? color}) {
    canvas.drawRRect(r.shift(const Offset(0, 6)), Paint()..color = AppColors.navy.withValues(alpha: isDark ? 0.35 : 0.10)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(r, Paint()..color = color ?? paper);
  }

  void _icon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _check(Canvas canvas, Offset c, double r, double fill) {
    canvas.drawCircle(c, r, Paint()..color = fill > 0 ? AppColors.royal : line);
    if (fill > 0) {
      final p = Path()
        ..moveTo(c.dx - r * 0.45, c.dy)
        ..lineTo(c.dx - r * 0.1, c.dy + r * 0.35)
        ..lineTo(c.dx + r * 0.5, c.dy - r * 0.35);
      final metric = p.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * fill),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.28
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // --- Scenes ---

  /// Runner in a liquid orb with the app's four pillars orbiting.
  void _welcome(Canvas canvas) {
    const c = Offset(100, 105);
    canvas.drawCircle(
      c,
      44,
      Paint()..shader = const LinearGradient(colors: [AppColors.pink, Color(0xFF4F7FE0), AppColors.royal], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(Rect.fromCircle(center: c, radius: 44)),
    );
    _icon(canvas, Icons.directions_run_rounded, c + Offset(0, 2 * wave()), 50, Colors.white);
    const icons = [Icons.check_rounded, Icons.local_fire_department_rounded, Icons.flag_rounded, Icons.auto_stories_rounded];
    const colors = [AppColors.royal, AppColors.warning, AppColors.accent, AppColors.sky];
    for (var i = 0; i < 4; i++) {
      final a = t * 2 * math.pi + i * math.pi / 2;
      final p = c + Offset(math.cos(a) * 74, math.sin(a) * 62);
      canvas.drawCircle(p + const Offset(0, 3), 17, Paint()..color = AppColors.navy.withValues(alpha: 0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(p, 17, Paint()..color = paper);
      _icon(canvas, icons[i], p, 18, colors[i]);
    }
  }

  /// Clipboard whose items tick themselves off one by one.
  void _tasks(Canvas canvas) {
    final board = RRect.fromLTRBR(52, 40, 148, 170, const Radius.circular(14));
    _card(canvas, board);
    canvas.drawRRect(RRect.fromLTRBR(80, 32, 120, 48, const Radius.circular(6)), Paint()..color = AppColors.royal);
    for (var i = 0; i < 3; i++) {
      final y = 76.0 + i * 30;
      final fill = ((t * 4) - i).clamp(0.0, 1.0);
      _check(canvas, Offset(72, y), 8, fill);
      canvas.drawRRect(RRect.fromLTRBR(88, y - 4, 132 - i * 8, y + 4, const Radius.circular(4)), Paint()..color = line);
    }
    canvas.save();
    canvas.translate(150, 132 + 4 * wave());
    canvas.rotate(-0.5);
    _icon(canvas, Icons.edit_rounded, Offset.zero, 34, AppColors.accent);
    canvas.restore();
  }

  /// Sprouting plant with a week of streak dots beneath.
  void _habits(Canvas canvas) {
    final sway = 0.08 * wave();
    final pot = Path()
      ..moveTo(70, 120)
      ..lineTo(130, 120)
      ..lineTo(122, 160)
      ..lineTo(78, 160)
      ..close();
    canvas.drawPath(pot, Paint()..shader = const LinearGradient(colors: [Color(0xFF4F7FE0), AppColors.royal]).createShader(const Rect.fromLTRB(70, 120, 130, 160)));
    canvas.drawRRect(RRect.fromLTRBR(66, 114, 134, 124, const Radius.circular(5)), Paint()..color = AppColors.navy);
    canvas.save();
    canvas.translate(100, 116);
    canvas.rotate(sway);
    final stem = Paint()
      ..color = AppColors.success
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(0, 0)..quadraticBezierTo(-4, -30, 0, -58), stem);
    void leaf(double y, double dir, double scale) {
      canvas.save();
      canvas.translate(0, y);
      canvas.rotate(dir * (0.7 + sway));
      canvas.drawOval(Rect.fromLTWH(0, -9 * scale, 30 * scale, 18 * scale), Paint()..color = const Color(0xFF3FCCB0));
      canvas.restore();
    }

    leaf(-22, -1, 0.9);
    leaf(-36, 1, 1);
    leaf(-50, -1, 0.75);
    canvas.drawCircle(const Offset(0, -62), 9, Paint()..color = AppColors.pink);
    canvas.restore();
    for (var i = 0; i < 7; i++) {
      final on = i < ((t * 9).floor() % 9).clamp(0, 7);
      canvas.drawCircle(Offset(55 + i * 15.0, 180), 5, Paint()..color = on ? AppColors.warning : line);
    }
  }

  /// Mountains with a waving flag at the summit and a dotted trail.
  void _goals(Canvas canvas) {
    canvas.drawCircle(Offset(150, 58 + 3 * wave()), 14, Paint()..color = AppColors.pink.withValues(alpha: 0.85));
    canvas.drawPath(Path()..moveTo(30, 170)..lineTo(78, 92)..lineTo(126, 170)..close(), Paint()..color = AppColors.lavender);
    canvas.drawPath(Path()..moveTo(64, 170)..lineTo(118, 64)..lineTo(176, 170)..close(), Paint()..color = AppColors.royal);
    canvas.drawPath(Path()..moveTo(105, 90)..lineTo(118, 64)..lineTo(131, 90)..lineTo(124, 84)..lineTo(118, 92)..lineTo(111, 84)..close(), Paint()..color = Colors.white);
    final pole = Paint()
      ..color = isDark ? Colors.white : AppColors.navy
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(118, 66), const Offset(118, 36), pole);
    final f = wave(0, 2) * 3;
    canvas.drawPath(
      Path()
        ..moveTo(118, 36)
        ..quadraticBezierTo(128, 36 + f, 140, 40)
        ..lineTo(140, 40)
        ..quadraticBezierTo(129, 44 - f, 118, 50)
        ..close(),
      Paint()..color = AppColors.accent,
    );
    final dots = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 6; i++) {
      final p = i / 5;
      canvas.drawCircle(Offset(80 + 30 * p + 6 * math.sin(p * 6), 166 - 70 * p), 2.2, dots);
    }
  }

  /// Open notebook with a pen writing and a heart floating up.
  void _journal(Canvas canvas) {
    final left = Path()..moveTo(100, 66)..quadraticBezierTo(74, 56, 40, 64)..lineTo(40, 156)..quadraticBezierTo(74, 148, 100, 158)..close();
    final right = Path()..moveTo(100, 66)..quadraticBezierTo(126, 56, 160, 64)..lineTo(160, 156)..quadraticBezierTo(126, 148, 100, 158)..close();
    canvas.drawPath(left.shift(const Offset(0, 6)), Paint()..color = AppColors.navy.withValues(alpha: 0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(left, Paint()..color = paper);
    canvas.drawPath(right, Paint()..color = isDark ? const Color(0xFF232E66) : const Color(0xFFF4F1FF));
    canvas.drawLine(const Offset(100, 66), const Offset(100, 158), Paint()..color = line..strokeWidth = 2);
    for (var i = 0; i < 4; i++) {
      final y = 86.0 + i * 16;
      canvas.drawLine(Offset(52, y), Offset(90, y), Paint()..color = line..strokeWidth = 3..strokeCap = StrokeCap.round);
      final written = ((t * 5) - i).clamp(0.0, 1.0);
      if (written > 0) {
        canvas.drawLine(Offset(110, y), Offset(110 + 38 * written, y), Paint()..color = AppColors.royal.withValues(alpha: 0.6)..strokeWidth = 3..strokeCap = StrokeCap.round);
      }
    }
    final row = (t * 5).floor().clamp(0, 3);
    final penX = 110 + 38 * ((t * 5) - row).clamp(0.0, 1.0);
    _icon(canvas, Icons.edit_rounded, Offset(penX + 8, 78.0 + row * 16), 22, AppColors.accent);
    final h = (t * 1.5) % 1;
    _icon(canvas, Icons.favorite_rounded, Offset(150, 60 - 30 * h), 18 + 6 * h, AppColors.pink.withValues(alpha: 1 - h));
  }

  /// Big check medal with confetti falling around it.
  void _allDone(Canvas canvas) {
    const c = Offset(100, 104);
    final pulse = 1 + 0.04 * wave();
    canvas.drawCircle(c, 50 * pulse, Paint()..color = AppColors.sky.withValues(alpha: 0.25));
    canvas.drawCircle(
      c,
      40,
      Paint()..shader = const LinearGradient(colors: [Color(0xFF4F7FE0), AppColors.royal]).createShader(Rect.fromCircle(center: c, radius: 40)),
    );
    _check(canvas, c, 30, 1);
    const colors = [AppColors.pink, AppColors.sky, AppColors.warning, AppColors.lavender, AppColors.accent];
    for (var i = 0; i < 10; i++) {
      final fall = (t + i * 0.1) % 1;
      final x = 30.0 + i * 15 + 6 * math.sin((fall + i) * 6);
      canvas.save();
      canvas.translate(x, 24 + 150 * fall);
      canvas.rotate(fall * 6 + i);
      canvas.drawRRect(RRect.fromLTRBR(-3, -5, 3, 5, const Radius.circular(2)), Paint()..color = colors[i % colors.length].withValues(alpha: 1 - fall * 0.7));
      canvas.restore();
    }
  }

  /// Bar chart whose bars grow, with a trend line on top.
  void _stats(Canvas canvas) {
    _card(canvas, RRect.fromLTRBR(36, 50, 164, 166, const Radius.circular(16)));
    const heights = [0.45, 0.7, 0.55, 0.9];
    final grow = Curves.easeOutBack.transform((t * 2).clamp(0.0, 1.0));
    final tops = <Offset>[];
    for (var i = 0; i < 4; i++) {
      final h = 80 * heights[i] * grow;
      final x = 56.0 + i * 26;
      canvas.drawRRect(RRect.fromLTRBR(x, 150 - h, x + 16, 150, const Radius.circular(5)), Paint()..color = i == 3 ? AppColors.royal : AppColors.lavender);
      tops.add(Offset(x + 8, 150 - h - 10));
    }
    final path = Path()..moveTo(tops.first.dx, tops.first.dy);
    for (final p in tops.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()..color = AppColors.accent..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (final p in tops) {
      canvas.drawCircle(p, 4, Paint()..color = AppColors.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.kind != kind || old.isDark != isDark;
}
