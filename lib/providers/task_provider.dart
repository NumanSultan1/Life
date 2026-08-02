import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
    final user = HiveService.getCurrentUser();
    _tasks = HiveService.getTasks(user);

    // Automatically inject "Drink 8 glasses of water" task if it does not exist
    if (user.isNotEmpty) {
      final hasWaterTask = _tasks.any((t) => t.id == 'water_drink_task');
      if (!hasWaterTask) {
        final box = Hive.box(HiveService.settingsBox);
        final waterCount = box.get('${user}_waterIntake', defaultValue: 0) as int;
        final isCompleted = waterCount >= 8;

        final waterTask = Task(
          id: 'water_drink_task',
          title: 'Drink 8 glasses of water',
          description: 'Stay hydrated to fuel your focus and memory!',
          category: 'Fitness',
          priority: 'High',
          dueDate: DateTime.now(),
          isCompleted: isCompleted,
        );
        _tasks.add(waterTask);
        HiveService.saveTask(waterTask, user);
      }
    }
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
    final user = HiveService.getCurrentUser();
    _tasks.add(task);
    await HiveService.saveTask(task, user);
    notifyListeners();
  }

  Future<void> toggleTaskStatus(String id) async {
    final user = HiveService.getCurrentUser();
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final oldCompleted = _tasks[index].isCompleted;
      final newCompleted = !oldCompleted;
      final updated = _tasks[index].copyWith(isCompleted: newCompleted);
      _tasks[index] = updated;
      await HiveService.saveTask(updated, user);

      // If this is the water drink task, update the water intake in settings accordingly!
      if (id == 'water_drink_task') {
        final box = Hive.box(HiveService.settingsBox);
        await box.put('${user}_waterIntake', newCompleted ? 8 : 0);
      }

      // Award 20 XP on task completion
      if (!oldCompleted) {
        await HiveService.addXp(20);
      }

      notifyListeners();
    }
  }

  Future<void> syncWaterTask(int count) async {
    final user = HiveService.getCurrentUser();
    final index = _tasks.indexWhere((t) => t.id == 'water_drink_task');
    if (index != -1) {
      final isCompleted = count >= 8;
      if (_tasks[index].isCompleted != isCompleted) {
        final updated = _tasks[index].copyWith(isCompleted: isCompleted);
        _tasks[index] = updated;
        await HiveService.saveTask(updated, user);

        // Award XP if completed
        if (isCompleted) {
          await HiveService.addXp(20);
        }
        notifyListeners();
      }
    }
  }

  Future<void> deleteTask(String id) async {
    final user = HiveService.getCurrentUser();
    _tasks.removeWhere((t) => t.id == id);
    await HiveService.deleteTask(id, user);
    notifyListeners();
  }
}
