import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/advanced_habit_learning_service.dart';

Task _task({required String id, DateTime? completedAt}) {
  return Task(
    id: id,
    title: 'کار $id',
    importance: 3,
    estimatedMinutes: 30,
    createdAt: DateTime(2026, 8, 1),
    completedAt: completedAt,
    status: TaskStatus.done,
    energy: EnergyLevel.medium,
  );
}

void main() {
  const svc = AdvancedHabitLearningService();

  test('X: helper task construction', () {
    final t = _task(id: '1', completedAt: DateTime(2026, 8, 5));
    expect(t.isDone, true);
    expect(t.status, TaskStatus.done);
  });

  test('Y: analyze empty', () {
    final p = svc.analyze(tasks: [], transactions: []);
    expect(p.hasEnoughData, isFalse);
    expect(p.streakDays, 0);
    expect(p.completionRate, 0);
  });
}
