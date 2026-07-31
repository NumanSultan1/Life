import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/empty_state.dart';

class JournalTab extends StatelessWidget {
  const JournalTab({super.key});

  void _showAddJournalModal(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String mood = '😊';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Write Journal Entry',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Reflections & Thoughts...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['😄', '😊', '😐', '😔', '😭'].map((e) {
                      return GestureDetector(
                        onTap: () => setStateModal(() => mood = e),
                        child: CircleAvatar(
                          backgroundColor: mood == e ? AppColors.accent.withValues(alpha: 0.3) : Colors.transparent,
                          child: Text(e, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          final newEntry = JournalEntry(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleController.text.trim(),
                            content: contentController.text.trim(),
                            mood: mood,
                            date: DateTime.now(),
                          );
                          Provider.of<JournalProvider>(context, listen: false).addEntry(newEntry);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<JournalProvider>(context);
    final journalList = provider.entries;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reflections & Journal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.star_rounded, color: Colors.amber),
                    onPressed: provider.toggleShowFavoritesOnly,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: provider.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search journal entries...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: journalList.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.auto_stories_rounded,
                        title: 'No Journal Entries',
                        description: 'Record your daily thoughts and reflections.',
                        buttonText: 'Write Entry',
                        onButtonPressed: () => _showAddJournalModal(context),
                      )
                    : ListView.builder(
                        itemCount: journalList.length,
                        itemBuilder: (context, index) {
                          final entry = journalList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            child: ListTile(
                              leading: Text(entry.mood, style: const TextStyle(fontSize: 28)),
                              title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                entry.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  entry.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: entry.isFavorite ? Colors.amber : Colors.grey,
                                ),
                                onPressed: () => provider.toggleFavorite(entry.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddJournalModal(context),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }
}
