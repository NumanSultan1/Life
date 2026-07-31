import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/hive_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedPriority = 'All';

  List<Task> get tasks {
    return _tasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          task.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || task.category == _selectedCategory;
      final matchesPriority = _selectedPriority == 'All' || task.priority == _selectedPriority;
      return matchesSearch && matchesCategory && matchesPriority;
    }).toList();
  }

  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get totalCount => _tasks.length;
  String get selectedCategory => _selectedCategory;
  String get selectedPriority => _selectedPriority;

  TaskProvider() {
    loadTasks();
  }

  void loadTasks() {
    _tasks = HiveService.getTasks();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setPriorityFilter(String priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    _tasks.add(task);
    await HiveService.saveTask(task);
    notifyListeners();
  }

  Future<void> toggleTaskStatus(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final updated = _tasks[index].copyWith(isCompleted: !_tasks[index].isCompleted);
      _tasks[index] = updated;
      await HiveService.saveTask(updated);
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await HiveService.deleteTask(id);
    notifyListeners();
  }
}
