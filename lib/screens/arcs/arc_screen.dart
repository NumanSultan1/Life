import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/arcs.dart';
import '../../providers/arc_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/feedback.dart';
import '../../widgets/liquid/liquid.dart';
import 'arc_reel.dart';
import 'arc_card.dart';

/// Photo background with a slow zoom ("Ken Burns") and a dark wash.
class ArcBackdrop extends StatefulWidget {
  final ArcDefinition arc;
  final double darken;

  const ArcBackdrop({super.key, required this.arc, this.darken = 0.55});

  @override
  State<ArcBackdrop> createState() => _ArcBackdropState();
}

class _ArcBackdropState extends State<ArcBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _zoom.stop();
    } else if (!_zoom.isAnimating) {
      _zoom.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arc = widget.arc;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _zoom,
          builder: (context, child) => Transform.scale(scale: 1 + 0.12 * Curves.easeInOut.transform(_zoom.value), child: child),
          child: Image.asset(arc.background, fit: BoxFit.cover),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: widget.darken * 0.6),
                arc.colors.first.withValues(alpha: widget.darken),
                Colors.black.withValues(alpha: widget.darken + 0.25),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ArcScreen extends StatefulWidget {
  final String arcId;

  const ArcScreen({super.key, required this.arcId});

  @override
  State<ArcScreen> createState() => _ArcScreenState();
}

class _ArcScreenState extends State<ArcScreen> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // The reel plays automatically the first time; it can be replayed later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ArcProvider>(context, listen: false);
      if (!provider.introSeen(widget.arcId)) _playReel(autoJoin: true);
    });
  }

  Future<void> _playReel({bool autoJoin = false}) async {
    final provider = Provider.of<ArcProvider>(context, listen: false);
    final arc = provider.definition(widget.arcId);
    final joined = provider.isJoined(widget.arcId);
    final blocked = provider.joinBlockedReason(widget.arcId) != null;
    final accepted = await ArcReel.show(context, arc, actionLabel: joined || blocked ? 'Back' : 'Start my ${arc.name}');
    if (blocked) {
      provider.markIntroSeen(widget.arcId);
      return;
    }
    provider.markIntroSeen(widget.arcId);
    if (accepted == true && !joined && autoJoin) await _join();
    if (accepted == true && !joined && !autoJoin) await _join();
  }

  Future<void> _join() async {
    final provider = Provider.of<ArcProvider>(context, listen: false);
    final blocked = provider.joinBlockedReason(widget.arcId);
    if (blocked != null) {
      showInfoSnackBar(context, blocked);
      return;
    }
    final current = provider.activeChallenge;
    if (current != null && current.id != widget.arcId) {
      final arc = provider.definition(widget.arcId);
      var switched = false;
      await _confirm(
        'Switch to ${arc.name}?',
        'You can do one challenge at a time. Starting ${arc.name} ends ${current.name} (Day ${provider.dayNumber(current.id)}).',
        'Switch',
        () async => switched = true,
      );
      if (!switched || !mounted) return;
    }
    await provider.join(widget.arcId);
    if (mounted) showInfoSnackBar(context, 'Day 1 starts now. Tick every rule before midnight 💪');
  }

  Future<void> _confirm(String title, String body, String action, Future<void> Function() onYes) async {
    final ok = await showLiquidConfirm(
      context,
      title: title,
      message: body,
      confirmLabel: action,
      icon: Icons.emoji_events_rounded,
      destructive: action == 'Delete' || action == 'Leave' || action == 'Restart',
    );
    if (ok) await onYes();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArcProvider>(context);
    final arc = provider.definition(widget.arcId);
    final joined = provider.isJoined(arc.id);
    final rules = provider.rules(arc.id);
    final done = provider.doneToday(arc.id);
    final day = provider.dayNumber(arc.id);
    final season = arc.seasonFor(DateTime.now());
    final quote = arc.motivation[DateTime.now().difference(DateTime(2024)).inDays % arc.motivation.length];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ArcBackdrop(arc: arc),
          SafeArea(
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Row(
                    children: [
                      GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      Tooltip(
                        message: 'Watch the motivation reel',
                        child: GlassIconButton(icon: Icons.play_arrow_rounded, onTap: _playReel),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: _editing ? 'Done editing' : 'Edit rules',
                        child: GlassIconButton(icon: _editing ? Icons.check_rounded : Icons.edit_rounded, onTap: () => setState(() => _editing = !_editing)),
                      ),
                      if (joined || arc.kind == ChallengeKind.custom) ...[
                        const SizedBox(width: 8),
                        GlassIconButton(
                          icon: Icons.more_horiz_rounded,
                          onTap: () async {
                            final v = await showLiquidActions<String>(
                              context,
                              title: arc.name,
                              actions: [
                                if (joined) const LiquidAction('restart', 'Restart from Day 1', Icons.restart_alt_rounded),
                                if (joined) const LiquidAction('leave', 'Leave this challenge', Icons.logout_rounded, destructive: true),
                                if (arc.kind == ChallengeKind.custom) const LiquidAction('edit', 'Edit challenge', Icons.edit_rounded),
                                if (arc.kind == ChallengeKind.custom) const LiquidAction('delete', 'Delete challenge', Icons.delete_outline_rounded, destructive: true),
                              ],
                            );
                            if (v == null || !context.mounted) return;
                            if (v == 'edit') {
                              showCreateChallengeSheet(context, editing: arc);
                            } else if (v == 'delete') {
                              _confirm('Delete ${arc.name}?', 'This removes the challenge and its progress.', 'Delete', () async {
                                await provider.deleteCustom(arc.id);
                                if (context.mounted) Navigator.pop(context);
                              });
                            } else if (v == 'restart') {
                              _confirm('Restart ${arc.name}?', 'Your progress resets to Day 1.', 'Restart', () => provider.join(arc.id));
                            } else {
                              _confirm('Leave ${arc.name}?', 'You can join again any time.', 'Leave', () => provider.leave(arc.id));
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Icon(arc.icon, color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      Text(arc.name.toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    arc.tagline,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    arc.seasonal
                        ? 'Season: ${DateFormat('d MMM').format(season.start)} – ${DateFormat('d MMM').format(season.end)} · ${arc.lengthDays} days'
                        : '${arc.lengthDays} days · start any time${arc.strict ? '' : ' · relaxed'}',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
                  ),
                  if (arc.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(arc.summary, style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9), height: 1.4)),
                  ],
                  const SizedBox(height: 20),
                  if (joined)
                    _ProgressPanel(
                      target: provider.targetDays(arc.id),
                      arc: arc,
                      day: arc.strict ? day : provider.completedDays(arc.id),
                      doneCount: done.where((id) => rules.any((r) => r.id == id)).length,
                      total: rules.length,
                      best: provider.bestRun(arc.id),
                      attempts: provider.attempts(arc.id),
                    ),
                  if (!joined) _StrictBanner(arc: arc),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          joined ? "TODAY'S RULES" : 'THE RULES',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                        ),
                      ),
                      if (_editing)
                        TextButton.icon(
                          onPressed: () => _editRule(context, arc.id, null),
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text(
                            'Add rule',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < rules.length; i++)
                    StaggerIn(
                      key: ValueKey(rules[i].id),
                      index: i,
                      child: _RuleTile(
                        rule: rules[i],
                        checked: done.contains(rules[i].id),
                        enabled: joined && !_editing,
                        editing: _editing,
                        onToggle: () => provider.toggleRule(arc.id, rules[i].id),
                        onEdit: () => _editRule(context, arc.id, rules[i]),
                        onDelete: () {
                          final rule = rules[i];
                          provider.deleteRule(arc.id, rule.id);
                          showUndoSnackBar(context, 'Rule removed', () => provider.saveRule(arc.id, rule));
                        },
                      ),
                    ),
                  if (_editing)
                    TextButton(
                      onPressed: () => _confirm('Reset rules?', 'Go back to the original ${arc.name} rules.', 'Reset', () => provider.resetRules(arc.id)),
                      child: const Text(
                        'Reset to the original rules',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                    ),
                  const SizedBox(height: 18),
                  GlassCard(
                    onLiquid: true,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.format_quote_rounded),
                            SizedBox(width: 6),
                            Text('TODAY\'S MOTIVATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(quote, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (arc.stills.isNotEmpty)
                    SizedBox(
                      height: 140,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final still in arc.stills)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(still, width: 220, height: 140, fit: BoxFit.cover),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!joined && provider.joinBlockedReason(arc.id) != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(child: Text(provider.joinBlockedReason(arc.id)!, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35))),
                        ],
                      ),
                    )
                  else if (!joined)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: arc.colors.first,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _join,
                      icon: Icon(arc.icon),
                      label: Text('Start my ${arc.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    arc.kind == ChallengeKind.custom ? '' : 'Videos and photos: Mixkit (free licence).',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editRule(BuildContext context, String arcId, ArcRule? rule) async {
    final provider = Provider.of<ArcProvider>(context, listen: false);
    final title = TextEditingController(text: rule?.title ?? '');
    final detail = TextEditingController(text: rule?.detail ?? '');
    var icon = rule?.icon ?? ruleIcons.first;
    await showLiquidSheet(
      context: context,
      title: rule == null ? 'Add a rule' : 'Edit rule',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setStateModal) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetLabel('Rule'),
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'e.g. 50 push-ups'),
            ),
            const SheetLabel('Details (optional)'),
            TextField(
              controller: detail,
              decoration: const InputDecoration(hintText: 'How or when'),
            ),
            const SheetLabel('Icon'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final ic in ruleIcons)
                  Pressable(
                    onTap: () => setStateModal(() => icon = ic),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ic == icon ? AppColors.royal : AppColors.accentOn(context).withValues(alpha: 0.1),
                      ),
                      child: Icon(ic, color: ic == icon ? Colors.white : AppColors.accentOn(context), size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: 'Save rule',
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                provider.saveRule(
                  arcId,
                  (rule ?? ArcRule(id: 'c_${DateTime.now().millisecondsSinceEpoch}', title: '')).copyWith(
                    title: title.text.trim(),
                    detail: detail.text.trim(),
                    icon: icon,
                  ),
                );
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StrictBanner extends StatelessWidget {
  final ArcDefinition arc;

  const _StrictBanner({required this.arc});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onLiquid: true,
      highlighted: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              arc.strict
                  ? 'Strict rules: tick every rule each day. Miss even one and the challenge restarts at Day 1. Finish all ${arc.seasonal ? 'days until the season ends' : '${arc.lengthDays} days'} to complete it.'
                  : 'Relaxed: tick every rule to count the day. Missed days don\'t restart you. Complete ${arc.seasonal ? 'every day until the season ends' : '${arc.lengthDays} days'} to finish.',
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final ArcDefinition arc;
  final int day, doneCount, total, best, attempts, target;

  const _ProgressPanel({required this.arc, required this.target, required this.day, required this.doneCount, required this.total, required this.best, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final progress = (day / target).clamp(0.0, 1.0);
    return GlassCard(
      onLiquid: true,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: arc.colors.last,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DAY',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.5),
                    ),
                    Text('$day', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
                    Text('of $target', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doneCount >= total ? 'Today is complete ✅' : '$doneCount of $total rules done today',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : doneCount / total,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Best run: $best days${attempts > 0 ? ' · Restarts: $attempts' : ''}',
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final ArcRule rule;
  final bool checked, enabled, editing;
  final VoidCallback onToggle, onEdit, onDelete;

  const _RuleTile({
    required this.rule,
    required this.checked,
    required this.enabled,
    required this.editing,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onLiquid: true,
      highlighted: checked,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      onTap: enabled ? onToggle : (editing ? onEdit : null),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: checked ? Colors.white : Colors.white.withValues(alpha: 0.2)),
            child: Icon(checked ? Icons.check_rounded : rule.icon, size: 20, color: checked ? AppColors.royal : Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white,
                  ),
                ),
                if (rule.detail.isNotEmpty) Text(rule.detail, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          if (editing) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}
