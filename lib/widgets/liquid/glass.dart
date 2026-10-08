import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'liquid_background.dart';
import 'motion.dart';

/// Frosted glass card. Use [onLiquid] when it sits on the vivid liquid
/// gradient (white text), otherwise it adapts to the light/dark page.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final bool onLiquid;
  final bool highlighted;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 24,
    this.onTap,
    this.onLiquid = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fill;
    final Color stroke;
    List<BoxShadow>? shadow;
    if (onLiquid) {
      fill = highlighted ? AppColors.navy.withValues(alpha: 0.38) : Colors.white.withValues(alpha: 0.16);
      stroke = Colors.white.withValues(alpha: highlighted ? 0.25 : 0.45);
    } else if (isDark) {
      fill = highlighted ? AppColors.royal.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06);
      stroke = Colors.white.withValues(alpha: 0.10);
    } else {
      fill = highlighted ? const Color(0xFFE9EDFF) : Colors.white.withValues(alpha: 0.82);
      stroke = Colors.white;
      shadow = [BoxShadow(color: AppColors.navy.withValues(alpha: 0.07), blurRadius: 28, offset: const Offset(0, 12))];
    }

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke, width: 1.2),
        boxShadow: shadow,
      ),
      child: onLiquid
          ? DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child))
          : DefaultTextStyle.merge(style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary), child: child),
    );

    if (onTap != null) card = Pressable(onTap: onTap, child: card);
    return card;
  }
}

/// Glowing liquid-gradient button with a press animation.
class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expand;

  const GlowButton({super.key, required this.label, this.onPressed, this.icon, this.height = 56, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2)),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: onPressed,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.royal.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
              BoxShadow(color: AppColors.pink.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(-6, 6)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LiquidBackground(
              period: const Duration(seconds: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.2),
                ),
                child: Center(
                  widthFactor: expand ? null : 1,
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 32), child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small round frosted icon button (back, filter, close...).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool onLiquid;
  final double size;
  final Widget? badge;

  const GlassIconButton({super.key, required this.icon, this.onTap, this.onLiquid = true, this.size = 42, this.badge});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = onLiquid ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.ink);
    return Pressable(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onLiquid ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white),
              border: Border.all(color: Colors.white.withValues(alpha: onLiquid ? 0.45 : (isDark ? 0.1 : 1))),
              boxShadow: onLiquid || isDark ? null : [BoxShadow(color: AppColors.navy.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Icon(icon, color: fg, size: size * 0.48),
          ),
          if (badge != null) Positioned(right: -2, top: -2, child: badge!),
        ],
      ),
    );
  }
}

/// Pill-shaped label, e.g. priority or XP chips.
class GlassPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool onLiquid;

  const GlassPill({super.key, required this.text, this.color = AppColors.royal, this.icon, this.onLiquid = false});

  @override
  Widget build(BuildContext context) {
    final fg = onLiquid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onLiquid ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: onLiquid ? Border.all(color: Colors.white.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
