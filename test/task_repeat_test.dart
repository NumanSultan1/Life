import 'package:flutter_test/flutter_test.dart';
import 'package:vortextech_appdev_week4/models/task.dart';

void main() {
  // Monday 6 Oct 2025, 9:00.
  final start = DateTime(2025, 10, 6, 9);

  Task task(String repeat, {List<String> done = const []}) => Task(id: 't', title: 'T', dueDate: start, repeat: repeat, completedDates: done);

  test('weekly tasks come back on the same weekday', () {
    final t = task('weekly');
    expect(t.occursOn(DateTime(2025, 10, 13)), isTrue); // next Monday
    expect(t.occursOn(DateTime(2025, 10, 14)), isFalse);
    expect(t.occursOn(DateTime(2025, 9, 29)), isFalse); // before it started
  });

  test('weekday tasks skip weekends', () {
    final t = task('weekdays');
    expect(t.occursOn(DateTime(2025, 10, 10)), isTrue); // Friday
    expect(t.occursOn(DateTime(2025, 10, 11)), isFalse); // Saturday
  });

  test('monthly tasks come back on the same date', () {
    final t = task('monthly');
    expect(t.occursOn(DateTime(2025, 11, 6)), isTrue);
    expect(t.occursOn(DateTime(2025, 11, 7)), isFalse);
  });

  test('completion is tracked per day for repeating tasks', () {
    final t = task('daily', done: ['2025-10-07']);
    expect(t.isDoneOn(DateTime(2025, 10, 7)), isTrue);
    expect(t.isDoneOn(DateTime(2025, 10, 8)), isFalse);
  });

  test('next reminder skips days already done', () {
    final t = task('daily', done: ['2025-10-07']);
    final next = t.nextDue(DateTime(2025, 10, 7, 8));
    expect(next, DateTime(2025, 10, 8, 9));
  });

  test('subtasks survive saving and loading', () {
    final t = Task(id: 't', title: 'T', dueDate: start, subtasks: const [Subtask('a', done: true), Subtask('b')]);
    final back = Task.fromMap(t.toMap());
    expect(back.subtasks.map((s) => s.title), ['a', 'b']);
    expect(back.subtasks.first.done, isTrue);
  });
}
