import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/liquid/liquid.dart';

const _prompts = [
  "What is one thing that made you smile today? 😊",
  "What was the biggest challenge you faced today, and how did you handle it? 💪",
  "What are three things you are extremely grateful for today? ✨",
  "How did you move closer to your long-term goals today? 🎯",
  "Describe a moment from today that you want to remember forever. 📖",
  "What is one thing you can do tomorrow to make it an amazing day? 🌟"
];

Future<void> showJournalSheet(BuildContext context) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  String mood = '😊';

  return showLiquidSheet(
    context: context,
    title: 'New Reflection',
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
            const SheetLabel('Reflections & Thoughts'),
            TextField(controller: contentController, maxLines: 5, decoration: const InputDecoration(hintText: 'Write freely...')),
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
              label: 'Save Entry',
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  final newEntry = JournalEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    mood: mood,
                    date: DateTime.now(),
                  );
                  Provider.of<JournalProvider>(sheetContext, listen: false).addEntry(newEntry);
                  Navigator.pop(sheetContext);
                }
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
              subtitle: 'Reflections & thoughts · ${journalList.length} entries',
              actions: [
                GlassIconButton(
                  icon: Icons.star_rounded,
                  onTap: provider.toggleShowFavoritesOnly,
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
                  title: 'No Journal Entries',
                  description: 'Record your daily thoughts and reflections.',
                  buttonText: 'Write Entry',
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
                Text(entry.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(DateFormat('EEE, d MMM · h:mm a').format(entry.date), style: TextStyle(fontSize: 11.5, color: secondary, fontWeight: FontWeight.w600)),
                if (entry.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(entry.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: secondary, height: 1.4)),
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
