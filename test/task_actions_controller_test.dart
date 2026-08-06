import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/tasks/task_actions_controller.dart';
import 'package:smart_day_planner/domain/repositories/task_repository_port.dart';
import 'package:smart_day_planner/models/task.dart';

import 'fakes/fake_platform_services.dart';

void main() {
  test('saveTask adds task and schedules reminder', () async {
    final tasks = FakeTaskRepository();
    final notifications = FakeNotificationService();
    final controller = TaskActionsController();
    final task = Task(
      id: 't1',
      title: 'تماس با مشتری',
      createdAt: DateTime(2026, 1, 1),
      dueAt: DateTime(2026, 1, 2),
    );

    await controller.saveTask(
      repository: tasks,
      notificationService: notifications,
      task: task,
      isNew: true,
    );

    expect(tasks.tasks, hasLength(1));
    expect(notifications.scheduledTaskIds, ['t1']);
  });

  test('completeTask marks task done and cancels reminder', () async {
    final tasks = FakeTaskRepository();
    final notifications = FakeNotificationService();
    final controller = TaskActionsController();
    final task = Task(id: 't1', title: 'پروژه', createdAt: DateTime(2026, 1, 1));
    await tasks.add(task);

    await controller.completeTask(
      repository: tasks,
      notificationService: notifications,
      task: task,
      actualMinutes: 45,
    );

    expect(tasks.tasks.single.isDone, isTrue);
    expect(tasks.tasks.single.actualMinutes, 45);
    expect(notifications.cancelledTaskIds, ['t1']);
  });
}

class FakeTaskRepository implements TaskRepositoryPort {
  @override
  final List<Task> tasks = [];

  @override
  Future<void> add(Task task) async => tasks.add(task);

  @override
  Future<void> update(Task task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    tasks[index] = task;
  }

  @override
  Future<void> delete(String id) async => tasks.removeWhere((task) => task.id == id);

  @override
  Future<void> togglePin(String id) async {}

  @override
  Future<void> complete(String id, {required int actualMinutes}) async {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    tasks[index] = tasks[index].copyWith(
      status: TaskStatus.done,
      actualMinutes: actualMinutes,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<void> reopen(String id) async {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    tasks[index] = tasks[index].copyWith(status: TaskStatus.todo, clearActualMinutes: true, clearCompletedAt: true);
  }

  @override
  Future<void> replaceAll(List<Task> values) async {
    tasks
      ..clear()
      ..addAll(values);
  }
}
