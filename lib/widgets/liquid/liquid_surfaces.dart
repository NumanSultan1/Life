import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'glass.dart';
import 'liquid_background.dart';
import 'wave.dart';

/// Page header on the liquid gradient with a dipping wave at the bottom.
class LiquidHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Replaces the title text (e.g. a tappable account switcher).
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? bottom;

  const LiquidHeader({super.key, required this.title, this.subtitle, this.titleWidget, this.leading, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    return AnimatedWaveClip(
      edge: WaveEdge.bottom,
      depth: 26,
      ripple: 3,
      child: LiquidBackground(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 46),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget ?? Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
                if (bottom != null) ...[const SizedBox(height: 18), bottom!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The liquid "sheet" that rises from the bottom with a hump-shaped
/// wave edge and a chevron handle, as on the reference home screen.
class LiquidSheet extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const LiquidSheet({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 44, 20, 130)});

  @override
  State<LiquidSheet> createState() => _LiquidSheetState();
}

class _LiquidSheetState extends State<LiquidSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final Animation<double> _curve = CurvedAnimation(parent: _rise, curve: Curves.easeOutQuart);

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Transform.translate(offset: Offset(0, 160 * (1 - _curve.value)), child: Opacity(opacity: _curve.value, child: child)),
      child: AnimatedWaveClip(
        depth: 22,
        ripple: 3,
        child: LiquidBackground(
          child: Stack(
            children: [
              Padding(padding: widget.padding, child: widget.child),
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white.withValues(alpha: 0.85), size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet with a liquid wave header and a title, like
/// the reference "Add Habit" screen.
Future<T?> showLiquidSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: 0.35),
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.88),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedWaveClip(
                edge: WaveEdge.bottom,
                depth: 18,
                ripple: 3,
                child: LiquidBackground(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 38),
                    child: Row(
                      children: [
                        GlassIconButton(icon: Icons.arrow_back_rounded, size: 40, onTap: () => Navigator.of(sheetContext).pop()),
                        Expanded(
                          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    child: builder(sheetContext),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Section label used inside sheets ("Habit Title", "Choose an Activity").
class SheetLabel extends StatelessWidget {
  final String text;

  const SheetLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

/// Slider with a gradient track, glossy thumb and a pink value bubble
/// that pops while dragging.
class BubbleSlider extends StatefulWidget {
  final double value; // 0..1
  final ValueChanged<double> onChanged;
  final String Function(double) labelBuilder;

  const BubbleSlider({super.key, required this.value, required this.onChanged, required this.labelBuilder});

  @override
  State<BubbleSlider> createState() => _BubbleSliderState();
}

class _BubbleSliderState extends State<BubbleSlider> {
  bool _dragging = false;

  void _update(Offset local, double width) {
    widget.onChanged((local.dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumb = 26.0;
        final width = constraints.maxWidth;
        final x = widget.value * (width - thumb);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            setState(() => _dragging = true);
            _update(d.localPosition, width);
          },
          onHorizontalDragUpdate: (d) => _update(d.localPosition, width),
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onTapDown: (d) => _update(d.localPosition, width),
          child: SizedBox(
            height: 74,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 50,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE3E6F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 50,
                  child: Container(
                    width: x + thumb / 2,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.pink, AppColors.lavender, AppColors.royal]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  left: x,
                  top: 41,
                  child: AnimatedScale(
                    scale: _dragging ? 1.2 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFF6F8FE8), AppColors.navy], center: Alignment(-0.3, -0.4)),
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [BoxShadow(color: AppColors.royal.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (x + thumb / 2 - 36).clamp(0.0, width - 72),
                  top: 0,
                  child: AnimatedScale(
                    scale: _dragging ? 1.12 : 1,
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 72,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.pink,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Text(widget.labelBuilder(widget.value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Round icon choices; the selected one fills with royal blue.
class IconChoiceGrid extends StatelessWidget {
  final Map<String, IconData> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const IconChoiceGrid({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      children: options.entries.map((e) {
        final isSelected = e.key == selected;
        return Tooltip(
          message: e.key,
          child: GestureDetector(
            onTap: () => onSelected(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.royal : (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.fieldBg),
                boxShadow: isSelected ? [BoxShadow(color: AppColors.royal.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))] : null,
              ),
              child: AnimatedScale(
                scale: isSelected ? 1.12 : 1,
                duration: const Duration(milliseconds: 260),
                child: Icon(e.value, color: isSelected ? Colors.white : (isDark ? AppColors.sky : AppColors.royal), size: 24),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
