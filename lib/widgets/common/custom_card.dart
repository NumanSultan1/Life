import 'package:flutter/material.dart';
import '../liquid/glass.dart';

/// Kept for existing callers; renders as a frosted [GlassCard].
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double borderRadius;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.borderRadius = 24.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      radius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }
}
