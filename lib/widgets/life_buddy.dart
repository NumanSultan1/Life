import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';

/// Buddy, the assistant's mascot: a chubby, glossy blob with big eyes that
/// blink and look around, rosy cheeks and a little glowing antenna. It
/// gently "breathes" and bobs. [listening] makes it perk up and glow.
class LifeBuddy extends StatefulWidget {
  final double size;
  final bool listening;
  final bool animate;

  const LifeBuddy({super.key, this.size = 64, this.listening = false, this.animate = true});

  @override
  State<LifeBuddy> createState() => _LifeBuddyState();
}

class _LifeBuddyState extends State<LifeBuddy> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  final _random = math.Random();
  Offset _look = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _breath.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  Timer? _blinkTimer;

  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _random.nextInt(2600)), () async {
      if (!mounted) return;
      await _blink.forward();
      if (!mounted) return;
      await _blink.reverse();
      if (!mounted) return;
      // Glance somewhere new every other blink.
      if (_random.nextBool()) setState(() => _look = Offset(_random.nextDouble() * 2 - 1, _random.nextDouble() * 1.2 - 0.6));
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breath.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: 'Life assistant',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breath, _blink]),
          builder: (context, _) {
            final t = reduceMotion ? 0.5 : Curves.easeInOut.transform(_breath.value);
            return TweenAnimationBuilder<Offset>(
              tween: Tween(end: _look),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutBack,
              builder: (context, look, _) => CustomPaint(
                painter: _BuddyPainter(breath: t, blink: _blink.value, look: look, listening: widget.listening),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BuddyPainter extends CustomPainter {
  final double breath, blink;
  final Offset look;
  final bool listening;

  _BuddyPainter({required this.breath, required this.blink, required this.look, required this.listening});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.save();
    // Bob up and down and squash slightly while "breathing".
    final bob = (breath - 0.5) * w * 0.05;
    final sx = 1.0 + 0.035 * breath, sy = 1.0 - 0.035 * breath;
    canvas.translate(w / 2, w / 2 + bob);
    canvas.scale(sx, sy);
    canvas.translate(-w / 2, -w / 2);

    final body = Rect.fromCenter(center: Offset(w * 0.5, w * 0.56), width: w * 0.86, height: w * 0.78);

    // Soft shadow on the ground.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, w * 0.97), width: w * (0.62 - 0.06 * breath), height: w * 0.08),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Antenna with a glowing tip.
    final stem = Paint()
      ..color = AppColors.violet
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tip = Offset(w * 0.6 + look.dx * w * 0.02, w * 0.08);
    canvas.drawPath(Path()..moveTo(w * 0.52, body.top + w * 0.03)..quadraticBezierTo(w * 0.56, w * 0.14, tip.dx, tip.dy), stem);
    canvas.drawCircle(
      tip,
      w * (listening ? 0.085 : 0.06),
      Paint()
        ..color = (listening ? AppColors.pink : const Color(0xFFFFD36E)).withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawCircle(tip, w * 0.045, Paint()..color = listening ? AppColors.pink : const Color(0xFFFFC94D));

    // Two little feet peeking out underneath.
    final foot = Paint()..color = const Color(0xFF5D6FE0);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.36, body.bottom - w * 0.01), width: w * 0.17, height: w * 0.1), foot);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.64, body.bottom - w * 0.01), width: w * 0.17, height: w * 0.1), foot);

    // Chubby body with a glossy gradient.
    final bodyPath = Path()..addRRect(RRect.fromRectAndRadius(body, Radius.elliptical(w * 0.43, w * 0.39)));
    canvas.drawPath(
      bodyPath.shift(Offset(0, w * 0.02)),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7FC8FF), AppColors.sky, Color(0xFF7A6CF0), AppColors.violet],
          stops: [0, 0.35, 0.8, 1],
        ).createShader(body),
    );
    // Belly glow and top shine.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, body.bottom - w * 0.1), width: w * 0.46, height: w * 0.16),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.33, body.top + w * 0.13), width: w * 0.26, height: w * 0.12),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // Little arms.
    final arm = Paint()..color = const Color(0xFF6E86F2);
    canvas.drawOval(Rect.fromCenter(center: Offset(body.left + w * 0.02, w * 0.66), width: w * 0.12, height: w * 0.18), arm);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(body.right - w * 0.02, w * (listening ? 0.56 : 0.66)), width: w * 0.12, height: w * 0.18),
      arm,
    );

    // Eyes: white, iris that follows [look], two highlights, eyelids blink.
    final eyeY = w * 0.5;
    for (final ex in [w * 0.36, w * 0.64]) {
      final eye = Rect.fromCenter(center: Offset(ex, eyeY), width: w * 0.2, height: w * 0.24 * (1 - 0.9 * blink));
      canvas.drawOval(eye, Paint()..color = Colors.white);
      if (blink < 0.6) {
        final pupil = Offset(ex + look.dx * w * 0.03, eyeY + look.dy * w * 0.03 + w * 0.01);
        canvas.save();
        canvas.clipPath(Path()..addOval(eye));
        canvas.drawCircle(pupil, w * 0.075, Paint()..color = AppColors.ink);
        canvas.drawCircle(pupil.translate(-w * 0.022, -w * 0.025), w * 0.026, Paint()..color = Colors.white);
        canvas.drawCircle(pupil.translate(w * 0.025, w * 0.022), w * 0.012, Paint()..color = Colors.white.withValues(alpha: 0.9));
        canvas.restore();
      }
    }

    // Rosy cheeks.
    final cheek = Paint()
      ..color = const Color(0xFFFF8FC8).withValues(alpha: 0.95)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.018);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.23, w * 0.64), width: w * 0.15, height: w * 0.085), cheek);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.77, w * 0.64), width: w * 0.15, height: w * 0.085), cheek);

    // Smile (opens a little when listening).
    final mouth = Rect.fromCenter(center: Offset(w * 0.5, w * 0.67), width: w * 0.16, height: w * (listening ? 0.12 : 0.08));
    if (listening) {
      canvas.drawOval(mouth, Paint()..color = AppColors.ink);
      canvas.drawOval(Rect.fromCenter(center: mouth.center.translate(0, mouth.height * 0.22), width: mouth.width * 0.6, height: mouth.height * 0.4), Paint()..color = AppColors.pink);
    } else {
      canvas.drawArc(
        mouth,
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BuddyPainter old) => old.breath != breath || old.blink != blink || old.look != look || old.listening != listening;
}

/// Whether the floating Buddy is shown (Profile setting), per user.
class BuddySettings {
  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _user => HiveService.getCurrentUser();

  static bool get visible => _box.get('${_user}_buddyVisible', defaultValue: true) as bool;

  /// Bumped when [visible] changes so the main screen can show/hide Buddy.
  static final changes = ValueNotifier<int>(0);

  static Future<void> setVisible(bool v) async {
    await _box.put('${_user}_buddyVisible', v);
    changes.value++;
  }

  /// Saved position as fractions of the screen (x 0 = left edge, 1 = right).
  static Offset get position {
    final raw = _box.get('${_user}_buddyPos');
    if (raw is List && raw.length == 2) return Offset((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    return const Offset(1, 0.62);
  }

  static Future<void> setPosition(Offset p) => _box.put('${_user}_buddyPos', [p.dx, p.dy]);
}

/// Buddy floating over the app: drag it anywhere, it snaps to the nearest
/// side; tap it to talk to Life.
class FloatingBuddy extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingBuddy({super.key, required this.onTap});

  @override
  State<FloatingBuddy> createState() => _FloatingBuddyState();
}

class _FloatingBuddyState extends State<FloatingBuddy> {
  static const _size = 68.0;
  late Offset _frac = BuddySettings.position;
  Offset? _drag; // pixel position while dragging
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final media = MediaQuery.of(context);
      final top = media.padding.top + 8, bottom = media.padding.bottom + 110; // above the nav bar
      final maxX = c.maxWidth - _size - 8, maxY = c.maxHeight - _size - bottom;
      final pos = _drag ?? Offset(8 + _frac.dx * (maxX - 8), top + _frac.dy * (maxY - top));
      return Stack(
        children: [
          AnimatedPositioned(
            duration: _drag == null ? const Duration(milliseconds: 420) : Duration.zero,
            curve: Curves.easeOutBack,
            left: pos.dx,
            top: pos.dy,
            child: Semantics(
              button: true,
              label: 'Talk to Life assistant',
              excludeSemantics: true,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: () {
                  setState(() => _pressed = false);
                  widget.onTap();
                },
                onPanStart: (_) => setState(() => _drag = pos),
                onPanUpdate: (d) => setState(() {
                  final p = (_drag ?? pos) + d.delta;
                  _drag = Offset(p.dx.clamp(0, c.maxWidth - _size), p.dy.clamp(top, maxY));
                }),
                onPanEnd: (_) {
                  final p = _drag ?? pos;
                  // Snap to the nearest side.
                  final fx = p.dx + _size / 2 < c.maxWidth / 2 ? 0.0 : 1.0;
                  final fy = ((p.dy - top) / math.max(1, maxY - top)).clamp(0.0, 1.0);
                  setState(() {
                    _frac = Offset(fx, fy);
                    _drag = null;
                  });
                  BuddySettings.setPosition(_frac);
                },
                child: AnimatedScale(
                  scale: _pressed ? 0.88 : (_drag != null ? 1.12 : 1),
                  duration: const Duration(milliseconds: 160),
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: const Hero(tag: 'life-buddy', child: LifeBuddy(size: _size)),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
