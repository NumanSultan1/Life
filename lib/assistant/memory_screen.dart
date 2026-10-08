import 'package:flutter/material.dart';
import '../services/voice_languages.dart';
import '../theme/app_colors.dart';
import '../widgets/liquid/liquid.dart';
import 'assistant_memory.dart';

const _meaningLabels = {
  'task': 'Add as a task',
  'reminder': 'Set a reminder',
  'journal': 'Save to journal',
  'water': 'Log a glass of water',
  'habit': 'Tick a habit',
  'mood': 'Log mood',
  'chat': 'Just chatting',
};

/// Everything the assistant has learned, which the user can edit or delete.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  Future<void> _addFact() async {
    final c = TextEditingController();
    final text = await showLiquidDialog<String>(
      context: context,
      title: 'Teach me something',
      icon: Icons.psychology_rounded,
      builder: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: c, autofocus: true, maxLines: 2, decoration: const InputDecoration(hintText: 'e.g. Abu is my father')),
          const SizedBox(height: 18),
          LiquidDialogActions(confirmLabel: 'Save', onCancel: () => Navigator.pop(d), onConfirm: () => Navigator.pop(d, c.text.trim())),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.isEmpty) return;
    await AssistantMemory.addFact(text);
    setState(() {});
  }

  Future<void> _editName() async {
    final c = TextEditingController(text: AssistantMemory.style.name);
    final name = await showLiquidDialog<String>(
      context: context,
      title: 'What should I call you?',
      icon: Icons.badge_rounded,
      builder: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmartName(controller: c),
          const SizedBox(height: 18),
          LiquidDialogActions(confirmLabel: 'Save', onCancel: () => Navigator.pop(d), onConfirm: () => Navigator.pop(d, c.text.trim())),
        ],
      ),
    );
    c.dispose();
    if (name == null) return;
    await AssistantMemory.setStyle(AssistantMemory.style.copyWith(name: name.isEmpty ? null : name));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final style = AssistantMemory.style;
    final facts = AssistantMemory.facts.reversed.toList();
    final phrases = AssistantMemory.phrases.entries.toList().reversed.toList();
    final fixes = AssistantMemory.corrections.entries.toList();
    final meanings = AssistantMemory.meanings.entries.toList().reversed.toList();
    final replies = AssistantMemory.replies.entries.toList().reversed.toList();
    final (up, down) = AssistantMemory.feedback;
    final textTheme = Theme.of(context).textTheme;

    Widget section(String title, String subtitle) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleMedium?.copyWith(fontSize: 17)),
              Text(subtitle, style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
            ],
          ),
        );

    Widget item(String title, String? subtitle, VoidCallback onDelete, {IconData icon = Icons.circle}) => GlassCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accentOn(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, textDirection: isRtlText(title) ? TextDirection.rtl : null, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (subtitle != null) Text(subtitle, style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Forget', icon: const Icon(Icons.close_rounded, size: 20), onPressed: onDelete),
            ],
          ),
        );

    Widget empty(String text) => Padding(padding: const EdgeInsets.all(8), child: Text(text, style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)));

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'Memory',
              subtitle: 'What your assistant has learned',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.badge_rounded, color: AppColors.accentOn(context)),
                          title: const Text('Call me', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(style.name ?? 'Your profile name'),
                          trailing: const Icon(Icons.edit_rounded, size: 18),
                          onTap: _editName,
                        ),
                        SwitchListTile(
                          secondary: Icon(Icons.short_text_rounded, color: AppColors.accentOn(context)),
                          title: const Text('Short replies', style: TextStyle(fontWeight: FontWeight.w700)),
                          value: style.short,
                          onChanged: (v) async {
                            await AssistantMemory.setStyle(style.copyWith(short: v));
                            setState(() {});
                          },
                        ),
                        SwitchListTile(
                          secondary: Icon(Icons.emoji_emotions_rounded, color: AppColors.accentOn(context)),
                          title: const Text('Use emoji', style: TextStyle(fontWeight: FontWeight.w700)),
                          value: style.emoji,
                          onChanged: (v) async {
                            await AssistantMemory.setStyle(style.copyWith(emoji: v));
                            setState(() {});
                          },
                        ),
                        SwitchListTile(
                          secondary: Icon(Icons.volume_up_rounded, color: AppColors.accentOn(context)),
                          title: const Text('Speak replies', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('English and Urdu. Pashto replies are shown as text.'),
                          value: style.speak,
                          onChanged: (v) async {
                            await AssistantMemory.setStyle(style.copyWith(speak: v));
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  if (up + down > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Your ratings: 👍 $up · 👎 $down', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  section('About you', 'Things you told me to remember'),
                  if (facts.isEmpty) empty('Nothing yet. Say "remember that…" in the chat, or add one here.'),
                  for (final f in facts)
                    item(f.text, null, () async {
                      await AssistantMemory.removeFact(f.text);
                      setState(() {});
                    }, icon: Icons.person_rounded),
                  OutlinedButton.icon(onPressed: _addFact, icon: const Icon(Icons.add_rounded), label: const Text('Add something')),
                  section('Meanings you taught me', 'Type "your words = English meaning" in the chat to add one'),
                  if (meanings.isEmpty) empty('For example: "za kha yam = I am fine" or "kitab rawra = add a task bring the book".'),
                  for (final m in meanings)
                    item(m.key, '= ${m.value}', () async {
                      await AssistantMemory.removeMeaning(m.key);
                      setState(() {});
                    }, icon: Icons.translate_rounded),
                  section('Replies you taught me', 'Type "your words means … and reply like …" to add one'),
                  if (replies.isEmpty) empty('For example: "sanga chal de means how are you and reply like za hm kha yama, ta sanga ye".'),
                  for (final r in replies)
                    item(r.key, '↩ ${r.value}', () async {
                      await AssistantMemory.removeReply(r.key);
                      setState(() {});
                    }, icon: Icons.reply_rounded),
                  section('Phrases you taught me', 'When you say these, I know what to do'),
                  if (phrases.isEmpty) empty('When I don\'t understand you, pick what you meant and I\'ll learn it.'),
                  for (final p in phrases)
                    item(
                      p.key,
                      '→ ${_meaningLabels[p.value.type] ?? p.value.type}${p.value.params['habit'] == null ? '' : ': ${p.value.params['habit']}'}',
                      () async {
                        await AssistantMemory.forgetPhrase(p.key);
                        setState(() {});
                      },
                      icon: Icons.record_voice_over_rounded,
                    ),
                  section('Words I heard wrong', 'Fixes from when you corrected me'),
                  if (fixes.isEmpty) empty('Tap one of your messages in the chat to fix what I heard.'),
                  for (final f in fixes)
                    item('${f.key} → ${f.value}', null, () async {
                      await AssistantMemory.removeCorrection(f.key);
                      setState(() {});
                    }, icon: Icons.spellcheck_rounded),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () async {
                      final ok = await showLiquidConfirm(context,
                          title: 'Forget everything?',
                          message: 'This clears all facts, taught phrases, word fixes and style settings.',
                          confirmLabel: 'Forget all',
                          icon: Icons.delete_forever_rounded,
                          destructive: true);
                      if (!ok) return;
                      await AssistantMemory.clearAll();
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Forget everything'),
                  ),
                  Text('Memory stays on your phone and is included in your backup.', textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A name field that flips to right-to-left for Urdu/Pashto names.
class SmartName extends StatelessWidget {
  final TextEditingController controller;

  const SmartName({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, v, _) => TextField(
        controller: controller,
        autofocus: true,
        textDirection: isRtlText(v.text) ? TextDirection.rtl : TextDirection.ltr,
        decoration: const InputDecoration(hintText: 'e.g. Numan'),
      ),
    );
  }
}
