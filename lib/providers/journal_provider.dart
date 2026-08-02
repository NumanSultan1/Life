import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../services/hive_service.dart';

class JournalProvider extends ChangeNotifier {
  List<JournalEntry> _entries = [];
  String _searchQuery = '';
  bool _showFavoritesOnly = false;

  List<JournalEntry> get entries {
    return _entries.where((entry) {
      final matchesSearch = entry.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.content.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFav = !_showFavoritesOnly || entry.isFavorite;
      return matchesSearch && matchesFav;
    }).toList();
  }

  JournalProvider() {
    loadEntries();
  }

  void loadEntries() {
    final user = HiveService.getCurrentUser();
    _entries = HiveService.getJournalEntries(user);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleShowFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  Future<void> addEntry(JournalEntry entry) async {
    final user = HiveService.getCurrentUser();
    _entries.insert(0, entry);
    await HiveService.saveJournalEntry(entry, user);

    // Award 30 XP for writing a journal entry
    await HiveService.addXp(30);

    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final user = HiveService.getCurrentUser();
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1) {
      final updated = _entries[index].copyWith(isFavorite: !_entries[index].isFavorite);
      _entries[index] = updated;
      await HiveService.saveJournalEntry(updated, user);
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    final user = HiveService.getCurrentUser();
    _entries.removeWhere((e) => e.id == id);
    await HiveService.deleteJournalEntry(id, user);
    notifyListeners();
  }
}
