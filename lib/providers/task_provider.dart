import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

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

  /// Whether the user has added any task of their own (not the built-in water one).
  bool get hasOwnTasks => _tasks.any((t) => t.id != 'water_drink_task');

  /// Day shown in the Plan tab's calendar strip.
  DateTime _selectedDay = DateTime.now();
  DateTime get selectedDay => _selectedDay;

  void selectDay(DateTime day) {
    _selectedDay = day;
    notifyListeners();
  }

  /// Search/category-filtered tasks for the selected day.
  List<Task> get tasksForSelectedDay => tasks.where((t) => t.isForDay(_selectedDay)).toList();

  /// Today's list (due today, overdue and still open, plus water).
  List<Task> get todayTasks => _tasks.where((t) => t.isForDay(DateTime.now())).toList();
  int get todayCompletedCount => todayTasks.where((t) => t.isCompleted).length;

  /// Number of tasks due on [day], for the calendar dots.
  int countForDay(DateTime day) => _tasks.where((t) => t.isForDay(day)).length;
  String get selectedCategory => _selectedCategory;
  String get selectedPriority => _selectedPriority;

  TaskProvider() {
    loadTasks();
  }

  void loadTasks() {
    final user = HiveService.getCurrentUser();
    _tasks = HiveService.getTasks(user);
    _resetDailyTrackers(user);

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

  /// Water and mood are per day: start fresh on a new day, and reopen the
  /// daily water task.
  void _resetDailyTrackers(String user) {
    final box = Hive.box(HiveService.settingsBox);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final last = box.get('${user}_dailyResetDate', defaultValue: '') as String;
    if (last == today) return;
    box.put('${user}_dailyResetDate', today);
    if (last.isEmpty) return; // first run for this profile: nothing to reset
    box.put('${user}_waterIntake', 0);
    box.put('${user}_moodToday', '😊');
    final i = _tasks.indexWhere((t) => t.id == 'water_drink_task');
    if (i != -1 && _tasks[i].isCompleted) {
      _tasks[i] = _tasks[i].copyWith(isCompleted: false, dueDate: DateTime.now());
      HiveService.saveTask(_tasks[i], user);
    }
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
    await _syncReminder(task);
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

      // Award 20 XP on completion; take it back if unticked so toggling
      // can't farm XP.
      await HiveService.addXp(oldCompleted ? -20 : 20);
      await _syncReminder(updated);

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

        // Award XP if completed, take it back if the goal is undone
        await HiveService.addXp(isCompleted ? 20 : -20);
        notifyListeners();
      }
    }
  }

  Future<void> deleteTask(String id) async {
    final user = HiveService.getCurrentUser();
    _tasks.removeWhere((t) => t.id == id);
    await HiveService.deleteTask(id, user);
    await NotificationService.cancel(NotificationService.taskId(id));
    notifyListeners();
  }

  /// A reminder fires at the due time while the task is still open.
  Future<void> _syncReminder(Task task) async {
    final id = NotificationService.taskId(task.id);
    if (task.hasReminder && !task.isCompleted) {
      await NotificationService.scheduleOnce(
        id: id,
        title: '⏰ ${task.title}',
        body: task.description.isNotEmpty ? task.description : 'Your task is due now. Tap to open Life.',
        when: task.dueDate,
      );
    } else {
      await NotificationService.cancel(id);
    }
  }

  /// Re-creates reminders for every open task (after logging in).
  Future<void> resyncReminders() async {
    for (final t in _tasks) {
      await _syncReminder(t);
    }
  }
}
