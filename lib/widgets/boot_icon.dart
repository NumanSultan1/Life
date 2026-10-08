import 'package:flutter/material.dart';

/// A small side-view boot (toe to the right), used for steps.
class BootIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const BootIcon({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: CustomPaint(size: Size.square(size), painter: _BootPainter(color ?? IconTheme.of(context).color ?? Colors.black)),
    );
  }
}

class _BootPainter extends CustomPainter {
  final Color color;
  _BootPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    // Upper: shaft, heel and rounded toe.
    final upper = Path()
      ..moveTo(5.2, 2.5)
      ..quadraticBezierTo(5.2, 1.6, 6.1, 1.6)
      ..lineTo(11.6, 1.6)
      ..quadraticBezierTo(12.5, 1.6, 12.5, 2.5)
      ..lineTo(12.7, 10.6)
      ..quadraticBezierTo(13.1, 12.3, 16.2, 13.0)
      ..quadraticBezierTo(21.6, 14.2, 21.8, 17.6)
      ..lineTo(21.8, 18.6)
      ..lineTo(3.0, 18.6)
      ..lineTo(3.0, 15.0)
      ..quadraticBezierTo(4.4, 13.8, 4.6, 11.0)
      ..close();
    canvas.drawPath(upper, paint);
    // Sole with a small gap above it, and a heel block.
    canvas.drawRRect(RRect.fromLTRBR(2.6, 19.6, 22.2, 22.4, const Radius.circular(1.2)), paint);
    // Laces and the cuff cut out of the upper.
    final clear = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(12.6, 6.0), const Offset(9.6, 6.0), clear);
    canvas.drawLine(const Offset(12.8, 9.0), const Offset(9.8, 9.0), clear);
    canvas.drawLine(const Offset(15.2, 12.0), const Offset(13.0, 13.6), clear);
    canvas.drawLine(const Offset(5.4, 4.2), const Offset(12.4, 4.2), clear..strokeWidth = 0.9);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BootPainter old) => old.color != color;
}
