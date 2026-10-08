import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import 'glass.dart';
import 'liquid_background.dart';
import 'liquid_surfaces.dart';
import 'motion.dart';
import 'wave.dart';

// App-styled replacements for Flutter's built-in dialogs, pickers and
// snackbars, so every popup matches the liquid-glass design.

/// A centered card with a liquid wave header. Returns what the buttons pop.
Future<T?> showLiquidDialog<T>({
  required BuildContext context,
  required String title,
  IconData icon = Icons.help_outline_rounded,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: title,
    barrierColor: AppColors.navy.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, _, _) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(dialogContext).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: isDark ? AppColors.darkCardBg : Colors.white,
                borderRadius: BorderRadius.circular(30),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedWaveClip(
                      edge: WaveEdge.bottom,
                      depth: 14,
                      ripple: 2,
                      child: LiquidBackground(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
                                child: Icon(icon, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          child: builder(dialogContext),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

/// Two buttons in the app style: a quiet "cancel" and a glowing action.
class LiquidDialogActions extends StatelessWidget {
  final String cancelLabel, confirmLabel;
  final VoidCallback onCancel, onConfirm;
  final bool destructive;

  const LiquidDialogActions({super.key, this.cancelLabel = 'Cancel', required this.confirmLabel, required this.onCancel, required this.onConfirm, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: onCancel,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accentOn(context).withValues(alpha: 0.35)),
              ),
              child: Text(cancelLabel, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentOn(context))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: destructive
              ? Pressable(
                  onTap: onConfirm,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(colors: [Color(0xFFE5577A), Color(0xFFF08A6C)]),
                      boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                )
              : GlowButton(label: confirmLabel, height: 52, onPressed: onConfirm),
        ),
      ],
    );
  }
}

/// "Are you sure?" in the app style. Returns true when confirmed.
Future<bool> showLiquidConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final ok = await showLiquidDialog<bool>(
    context: context,
    title: title,
    icon: icon,
    builder: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontSize: 14.5, height: 1.45)),
        const SizedBox(height: 22),
        LiquidDialogActions(
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          destructive: destructive,
          onCancel: () => Navigator.pop(c, false),
          onConfirm: () => Navigator.pop(c, true),
        ),
      ],
    ),
  );
  return ok == true;
}

/// One choice in [showLiquidActions].
class LiquidAction<T> {
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;

  const LiquidAction(this.value, this.label, this.icon, {this.destructive = false});
}

/// A list of actions in a liquid sheet (replaces popup menus).
Future<T?> showLiquidActions<T>(BuildContext context, {required String title, required List<LiquidAction<T>> actions}) {
  return showLiquidSheet<T>(
    context: context,
    title: title,
    builder: (c) => Column(
      children: [
        for (final a in actions)
          GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => Navigator.pop(c, a.value),
            child: Row(
              children: [
                Icon(a.icon, color: a.destructive ? AppColors.danger : AppColors.accentOn(c)),
                const SizedBox(width: 14),
                Expanded(child: Text(a.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: a.destructive ? AppColors.danger : null))),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
      ],
    ),
  );
}

// --- Time picker ---

/// Scroll wheels for hour, minute and AM/PM in a liquid sheet.
Future<TimeOfDay?> showLiquidTimePicker(BuildContext context, {required TimeOfDay initialTime, String title = 'Pick a time'}) {
  var hour = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
  var minute = initialTime.minute;
  var pm = initialTime.period == DayPeriod.pm;
  TimeOfDay result() => TimeOfDay(hour: (hour % 12) + (pm ? 12 : 0), minute: minute);

  return showLiquidSheet<TimeOfDay>(
    context: context,
    title: title,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        Widget quick(String label, TimeOfDay t) => Pressable(
              onTap: () => Navigator.pop(c, t),
              child: GlassPill(text: label, color: AppColors.royal),
            );
        return Column(
          children: [
            const SizedBox(height: 6),
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(colors: [AppColors.royal.withValues(alpha: 0.12), AppColors.pink.withValues(alpha: 0.18)]),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _Wheel(count: 12, initial: hour - 1, label: (i) => '${i + 1}', onChanged: (i) => hour = i + 1)),
                      const Text(':', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      Expanded(child: _Wheel(count: 60, initial: minute, label: (i) => i.toString().padLeft(2, '0'), onChanged: (i) => minute = i)),
                      Expanded(child: _Wheel(count: 2, initial: pm ? 1 : 0, label: (i) => i == 0 ? 'AM' : 'PM', onChanged: (i) => pm = i == 1, loop: false)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                quick('7:00 AM', const TimeOfDay(hour: 7, minute: 0)),
                quick('12:00 PM', const TimeOfDay(hour: 12, minute: 0)),
                quick('6:00 PM', const TimeOfDay(hour: 18, minute: 0)),
                quick('9:00 PM', const TimeOfDay(hour: 21, minute: 0)),
              ],
            ),
            const SizedBox(height: 20),
            GlowButton(label: 'Set time', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, result())),
          ],
        );
      },
    ),
  );
}

class _Wheel extends StatefulWidget {
  final int count, initial;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  final bool loop;

  const _Wheel({required this.count, required this.initial, required this.label, required this.onChanged, this.loop = true});

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller = FixedExtentScrollController(initialItem: widget.initial);
  late int _selected = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.titleLarge?.color ?? AppColors.ink;
    Widget item(int i) {
      final selected = i == _selected;
      return Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: selected ? 28 : 20,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            color: selected ? AppColors.accentOn(context) : color.withValues(alpha: 0.35),
          ),
          child: Text(widget.label(i)),
        ),
      );
    }

    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 52,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        final v = i % widget.count;
        setState(() => _selected = v);
        widget.onChanged(v);
      },
      childDelegate: widget.loop
          ? ListWheelChildLoopingListDelegate(children: List.generate(widget.count, item))
          : ListWheelChildListDelegate(children: List.generate(widget.count, item)),
    );
  }
}

// --- Date picker ---

/// A month calendar in a liquid sheet.
Future<DateTime?> showLiquidDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pick a date',
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  var selected = day(initialDate);
  var month = DateTime(selected.year, selected.month);
  final first = day(firstDate), last = day(lastDate);

  return showLiquidSheet<DateTime>(
    context: context,
    title: title,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) {
        final textTheme = Theme.of(c).textTheme;
        final accent = AppColors.accentOn(c);
        final today = day(DateTime.now());
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final leading = DateTime(month.year, month.month, 1).weekday - 1; // Monday first
        final canBack = DateTime(month.year, month.month, 0).isAfter(first.subtract(const Duration(days: 1)));
        final canForward = DateTime(month.year, month.month + 1, 1).isBefore(last.add(const Duration(days: 1)));

        Widget quick(String label, DateTime d) {
          final ok = !d.isBefore(first) && !d.isAfter(last);
          if (!ok) return const SizedBox.shrink();
          return Pressable(onTap: () => Navigator.pop(c, d), child: GlassPill(text: label, color: AppColors.royal));
        }

        return Column(
          children: [
            Row(
              children: [
                _NavButton(icon: Icons.chevron_left_rounded, enabled: canBack, onTap: () => setState(() => month = DateTime(month.year, month.month - 1))),
                Expanded(
                  child: Text(DateFormat('MMMM yyyy').format(month), textAlign: TextAlign.center, style: textTheme.titleMedium?.copyWith(fontSize: 17)),
                ),
                _NavButton(icon: Icons.chevron_right_rounded, enabled: canForward, onTap: () => setState(() => month = DateTime(month.year, month.month + 1))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(child: Text(d, textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                for (var n = 1; n <= daysInMonth; n++)
                  Builder(builder: (_) {
                    final d = DateTime(month.year, month.month, n);
                    final enabled = !d.isBefore(first) && !d.isAfter(last);
                    final isSelected = d == selected;
                    final isToday = d == today;
                    return Semantics(
                      button: enabled,
                      selected: isSelected,
                      label: DateFormat('EEEE d MMMM').format(d),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: enabled ? () => setState(() => selected = d) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected ? AppColors.primaryGradient : null,
                            border: isToday && !isSelected ? Border.all(color: accent, width: 1.5) : null,
                            boxShadow: isSelected ? [BoxShadow(color: AppColors.royal.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))] : null,
                          ),
                          child: Text(
                            '$n',
                            style: TextStyle(
                              fontWeight: isSelected || isToday ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected ? Colors.white : enabled ? null : textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                quick('Today', today),
                quick('Tomorrow', today.add(const Duration(days: 1))),
                quick('Next week', today.add(const Duration(days: 7))),
              ],
            ),
            const SizedBox(height: 18),
            GlowButton(label: 'Choose ${DateFormat('EEE d MMM').format(selected)}', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, selected)),
          ],
        );
      },
    ),
  );
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOn(context);
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.12)),
          child: Icon(icon, color: accent),
        ),
      ),
    );
  }
}
