import '../../utils/feedback.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/liquid/liquid.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/voice_input_button.dart';
import '../../services/voice_languages.dart';

const _prompts = [
  "What is one thing that made you smile today? 😊",
  "What was the biggest challenge you faced today, and how did you handle it? 💪",
  "What are three things you are extremely grateful for today? ✨",
  "How did you move closer to your long-term goals today? 🎯",
  "Describe a moment from today that you want to remember forever. 📖",
  "What is one thing you can do tomorrow to make it an amazing day? 🌟"
];

/// New entry, or edit [editing] (keeps its date and favourite).
Future<void> showJournalSheet(BuildContext context, {JournalEntry? editing}) {
  final titleController = TextEditingController(text: editing?.title);
  final contentController = TextEditingController(text: editing?.content);
  String mood = editing?.mood ?? '😊';

  return showLiquidSheet(
    context: context,
    title: editing == null ? 'New Reflection' : 'Edit Reflection',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setStateModal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SheetLabel('Title')),
                Pressable(
                  onTap: () => setStateModal(() => contentController.text = "${_prompts[Random().nextInt(_prompts.length)]}\n\n"),
                  child: const GlassPill(text: 'Inspire Me', icon: Icons.lightbulb_rounded, color: AppColors.accent),
                ),
              ],
            ),
            TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(hintText: 'Give today a name')),
            Row(
              children: [
                const Expanded(child: SheetLabel('Reflections & Thoughts')),
                VoiceInputButton(controller: contentController),
              ],
            ),
            SmartTextField(controller: contentController, hint: 'Write freely, or tap the mic and speak in your language...'),
            TranslateButton(controller: contentController),
            const SheetLabel('How do you feel?'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['😄', '😊', '😐', '😔', '😭'].map((e) {
                final selected = mood == e;
                return Pressable(
                  onTap: () => setStateModal(() => mood = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected ? AppColors.ringCenterGradient : null,
                      border: Border.all(color: selected ? AppColors.royal : Colors.transparent, width: 2),
                    ),
                    child: AnimatedScale(
                      scale: selected ? 1.25 : 1,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            GlowButton(
              label: editing == null ? 'Save Entry' : 'Save Changes',
              icon: Icons.check_rounded,
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  showInfoSnackBar(sheetContext, 'Give your entry a title first.');
                  return;
                }
                final provider = Provider.of<JournalProvider>(sheetContext, listen: false);
                if (editing != null) {
                  provider.updateEntry(editing.copyWith(title: titleController.text.trim(), content: contentController.text.trim(), mood: mood));
                } else {
                  provider.addEntry(JournalEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    mood: mood,
                    date: DateTime.now(),
                  ));
                }
                Navigator.pop(sheetContext);
              },
            ),
          ],
        );
      },
    ),
  );
}

class JournalTab extends StatelessWidget {
  const JournalTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<JournalProvider>(context);
    final journalList = provider.entries;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: LiquidHeader(
              title: 'Journal',
              subtitle: 'Write about your day · ${journalList.length} entries',
              actions: [
                Tooltip(
                  message: 'Show favorites only',
                  child: GlassIconButton(icon: Icons.star_rounded, onTap: provider.toggleShowFavoritesOnly),
                ),
              ],
              bottom: TextField(
                onChanged: provider.setSearchQuery,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search journal entries...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white),
                  fillColor: Colors.white.withValues(alpha: 0.18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          if (journalList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: EmptyStateWidget(
                  icon: Icons.auto_stories_rounded,
                  illustration: IllustrationKind.journal,
                  title: 'Write your first entry',
                  description: 'A few lines about your day helps you notice what went well. Tap "Inspire Me" if you need an idea.',
                  buttonText: 'Write an entry',
                  onButtonPressed: () => showJournalSheet(context),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = journalList[index];
                    return StaggerIn(
                      key: ValueKey(entry.id),
                      index: index,
                      child: _JournalCard(entry: entry, onFavorite: () => provider.toggleFavorite(entry.id)),
                    );
                  },
                  childCount: journalList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The whole entry, with right-to-left text for Urdu and Pashto.
void _showEntry(BuildContext context, JournalEntry entry) {
  final rtl = isRtlText(entry.content);
  final controller = TextEditingController(text: entry.content);
  showLiquidSheet(
    context: context,
    title: entry.title,
    builder: (c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(entry.mood, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Text(DateFormat('EEEE, d MMMM yyyy · h:mm a').format(entry.date), style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
        const SizedBox(height: 16),
        SelectableText(
          entry.content.isEmpty ? 'No text.' : entry.content,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          style: TextStyle(fontSize: rtl ? 18 : 15.5, height: rtl ? 1.8 : 1.55),
        ),
        const SizedBox(height: 8),
        TranslateButton(controller: controller),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) => value.text == entry.content
              ? const SizedBox.shrink()
              : GlassCard(padding: const EdgeInsets.all(14), child: Text(value.text, style: const TextStyle(height: 1.5))),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GlowButton(
                label: 'Edit',
                icon: Icons.edit_rounded,
                onPressed: () {
                  Navigator.pop(c);
                  showJournalSheet(context, editing: entry);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () async {
                  final ok = await showLiquidConfirm(c, title: 'Delete this entry?', message: '"${entry.title}" will be removed.', confirmLabel: 'Delete', icon: Icons.delete_outline_rounded, destructive: true);
                  if (!ok || !c.mounted) return;
                  final provider = Provider.of<JournalProvider>(c, listen: false);
                  Navigator.pop(c);
                  await provider.deleteEntry(entry.id);
                  if (context.mounted) {
                    showUndoSnackBar(context, 'Entry deleted', () => provider.restoreEntry(entry));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onFavorite;

  const _JournalCard({required this.entry, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).textTheme.bodyMedium?.color;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      onTap: () => _showEntry(context, entry),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.ringCenterGradient),
            child: Text(entry.mood, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, textDirection: isRtlText(entry.title) ? TextDirection.rtl : null, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(DateFormat('EEE, d MMM · h:mm a').format(entry.date), style: TextStyle(fontSize: 11.5, color: secondary, fontWeight: FontWeight.w600)),
                if (entry.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textDirection: isRtlText(entry.content) ? TextDirection.rtl : null,
                    style: TextStyle(fontSize: 13, color: secondary, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onFavorite,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                entry.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey(entry.isFavorite),
                color: entry.isFavorite ? const Color(0xFFF5B83D) : secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
