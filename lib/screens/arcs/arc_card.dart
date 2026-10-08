import '../../utils/feedback.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/arcs.dart';
import '../../providers/arc_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/liquid/liquid.dart';
import 'arc_screen.dart';

void openArc(BuildContext context, String arcId) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ArcScreen(arcId: arcId)));
}

void openChallengesHub(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesScreen()));
}

/// Photo card for a challenge: name, when it runs, and either the current
/// day and today's progress or an invitation to start.
class ArcCard extends StatelessWidget {
  final ArcDefinition arc;
  final double height;

  const ArcCard({super.key, required this.arc, this.height = 190});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArcProvider>(context);
    final joined = provider.isJoined(arc.id);
    final now = DateTime.now();
    final inSeason = arc.inSeason(now);
    final rules = provider.rules(arc.id);
    final done = provider.doneToday(arc.id).where((id) => rules.any((r) => r.id == id)).length;
    final progressDays = arc.strict ? provider.dayNumber(arc.id) : provider.completedDays(arc.id);

    final String status;
    if (joined) {
      status = arc.strict
          ? 'Day ${provider.dayNumber(arc.id)} of ${provider.targetDays(arc.id)} · $done/${rules.length} rules today'
          : '$progressDays of ${provider.targetDays(arc.id)} days done · $done/${rules.length} today';
    } else if (arc.seasonal) {
      final season = arc.seasonFor(now);
      status = inSeason ? 'In season now · tap to start' : '🔒 Opens ${DateFormat('d MMM').format(season.start)} · runs to ${DateFormat('d MMM').format(season.end)}';
    } else {
      status = '${arc.lengthDays} days · start any time';
    }

    return Pressable(
      onTap: () => openArc(context, arc.id),
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: arc.colors.first.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArcBackdrop(arc: arc, darken: 0.45),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(arc.icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            arc.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                        ),
                        if (joined) const GlassPill(text: 'JOINED', onLiquid: true) else if (inSeason) const GlassPill(text: 'IN SEASON', onLiquid: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      arc.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (joined)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (progressDays / provider.targetDays(arc.id)).clamp(0.0, 1.0),
                          minHeight: 7,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            status,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list of all challenges, grouped, with "create your own".
class ChallengesList extends StatelessWidget {
  const ChallengesList({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArcProvider>(context);
    final now = DateTime.now();
    final textTheme = Theme.of(context).textTheme;
    final joined = provider.joinedChallenges;
    final inSeason = arcDefinitions.where((a) => a.inSeason(now) && !provider.isJoined(a.id)).toList();
    final seasonal = arcDefinitions.where((a) => a.seasonal && !a.inSeason(now) && !provider.isJoined(a.id)).toList()
      ..sort((a, b) => a.seasonFor(now).start.compareTo(b.seasonFor(now).start));
    final anytime = arcDefinitions.where((a) => a.kind == ChallengeKind.anytime && !provider.isJoined(a.id)).toList();
    final custom = provider.customChallenges.where((a) => !provider.isJoined(a.id)).toList();

    var index = 0;
    Widget section(String title, String? subtitle, List<ArcDefinition> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 17)),
          if (subtitle != null) Text(subtitle, style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
          const SizedBox(height: 10),
          for (final arc in list)
            StaggerIn(
              index: index++,
              child: ArcCard(arc: arc),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pick one challenge and follow its daily rules. Strict challenges restart at Day 1 if you miss a rule.',
          style: textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        GlowButton(label: 'Create your own challenge', icon: Icons.add_rounded, onPressed: () => showCreateChallengeSheet(context)),
        const SizedBox(height: 6),
        section('Your active challenge', 'One at a time. Starting another one ends this.', joined),
        section('In season now', null, inSeason),
        section('Coming up', 'Seasonal arcs open only during their season', seasonal),
        section('Anytime challenges', 'Start whenever you\'re ready', anytime),
        section('Your challenges', 'Ones you created', custom),
      ],
    );
  }
}

/// Full-screen hub opened from Home.
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Challenges',
              subtitle: 'Arcs, 75 Hard, 75 Soft and your own',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 40), child: ChallengesList()),
          ],
        ),
      ),
    );
  }
}

/// Compact Home card: your active challenges, or an invitation to browse.
class ChallengesHomeCard extends StatelessWidget {
  const ChallengesHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ArcProvider>(context);
    final joined = provider.joinedChallenges;
    return GlassCard(
      onLiquid: true,
      onTap: () => openChallengesHub(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Challenges', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(
                      joined.isEmpty ? 'Pick one: Winter Arc, 75 Hard and more' : 'Your active challenge · tap to see all',
                      style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          for (final arc in joined.take(3)) ...[
            const SizedBox(height: 10),
            Pressable(
              onTap: () => openArc(context, arc.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(arc.icon, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(arc.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      '${provider.doneToday(arc.id).where((id) => provider.rules(arc.id).any((r) => r.id == id)).length}/${provider.rules(arc.id).length} today · Day ${provider.dayNumber(arc.id)}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Builder for a user's own challenge.
Future<void> showCreateChallengeSheet(BuildContext context, {ArcDefinition? editing}) {
  final provider = Provider.of<ArcProvider>(context, listen: false);
  final name = TextEditingController(text: editing?.name ?? '');
  final motto = TextEditingController(text: editing?.tagline ?? '');
  final ruleText = TextEditingController();
  var days = editing?.days ?? 30;
  var strict = editing?.strict ?? true;
  var icon = editing?.icon ?? Icons.emoji_events_rounded;
  var palette = editing == null ? 0 : challengePalettes.indexWhere((p) => p.first == editing.colors.first).clamp(0, challengePalettes.length - 1);
  var photo = editing?.background ?? challengePhotos.first;
  final rules = <ArcRule>[...?editing?.rules];
  const dayOptions = [7, 14, 21, 30, 45, 60, 75, 90, 100];

  return showLiquidSheet(
    context: context,
    title: editing == null ? 'Create a challenge' : 'Edit challenge',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setStateModal) {
        void addRule() {
          final t = ruleText.text.trim();
          if (t.isEmpty) return;
          setStateModal(() {
            rules.add(ArcRule(id: 'c_${DateTime.now().microsecondsSinceEpoch}', title: t, icon: Icons.check_circle_outline_rounded));
            ruleText.clear();
          });
        }

        final dayIndex = dayOptions.contains(days) ? dayOptions.indexOf(days) : 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetLabel('Name'),
            TextField(
              controller: name,
              decoration: const InputDecoration(hintText: 'e.g. No Sugar November'),
            ),
            const SheetLabel('Motto (optional)'),
            TextField(
              controller: motto,
              decoration: const InputDecoration(hintText: 'A line to keep you going'),
            ),
            const SheetLabel('How many days?'),
            BubbleSlider(
              value: dayIndex / (dayOptions.length - 1),
              labelBuilder: (v) => '${dayOptions[(v * (dayOptions.length - 1)).round()]} days',
              onChanged: (v) => setStateModal(() => days = dayOptions[(v * (dayOptions.length - 1)).round()]),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: strict,
              onChanged: (v) => setStateModal(() => strict = v),
              title: const Text('Strict mode', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(strict ? 'Miss a rule and you restart at Day 1' : 'Missed days just don\'t count'),
            ),
            const SheetLabel('Daily rules'),
            for (final r in rules)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(r.icon, color: AppColors.accentOn(context)),
                title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.close_rounded), onPressed: () => setStateModal(() => rules.remove(r))),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ruleText,
                    onSubmitted: (_) => addRule(),
                    decoration: const InputDecoration(hintText: 'Add a rule, e.g. 50 push-ups'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(tooltip: 'Add rule', onPressed: addRule, icon: const Icon(Icons.add_rounded)),
              ],
            ),
            const SheetLabel('Icon'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ic in ruleIcons)
                  GestureDetector(
                    onTap: () => setStateModal(() => icon = ic),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: ic == icon ? AppColors.royal : AppColors.accentOn(context).withValues(alpha: 0.1),
                      child: Icon(ic, size: 20, color: ic == icon ? Colors.white : AppColors.accentOn(context)),
                    ),
                  ),
              ],
            ),
            const SheetLabel('Colours'),
            Row(
              children: [
                for (var i = 0; i < challengePalettes.length; i++)
                  GestureDetector(
                    onTap: () => setStateModal(() => palette = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: challengePalettes[i]),
                        border: Border.all(color: i == palette ? AppColors.royal : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
            const SheetLabel('Background photo'),
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in challengePhotos)
                    GestureDetector(
                      onTap: () => setStateModal(() => photo = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p == photo ? AppColors.royal : Colors.transparent, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(p, width: 110, height: 80, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: editing == null ? 'Create challenge' : 'Save changes',
              onPressed: () async {
                addRule();
                if (name.text.trim().isEmpty || rules.isEmpty) {
                  showInfoSnackBar(sheetContext, 'Add a name and at least one rule.');
                  return;
                }
                final def = ArcDefinition.fromMap({
                  'id': editing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  'name': name.text.trim(),
                  'tagline': motto.text.trim().isEmpty ? '$days days. Your rules.' : motto.text.trim(),
                  'days': days,
                  'strict': strict,
                  'palette': palette,
                  'icon': icon.codePoint,
                  'background': photo,
                  'rules': rules.map((r) => r.toMap()).toList(),
                });
                await provider.saveCustom(def);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (editing == null && context.mounted) openArc(context, def.id);
              },
            ),
          ],
        );
      },
    ),
  );
}
