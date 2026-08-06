import '../../domain/services/notification_service_port.dart';
import '../../models/task.dart';
import '../../domain/repositories/task_repository_port.dart';

class TaskActionsController {
  const TaskActionsController();

  Future<void> saveTask({
    required TaskRepositoryPort repository,
    required NotificationServicePort notificationService,
    required Task task,
    required bool isNew,
  }) async {
    if (isNew) {
      await repository.add(task);
    } else {
      await repository.update(task);
    }
    await notificationService.scheduleTaskReminder(task);
  }

  Future<void> completeTask({
    required TaskRepositoryPort repository,
    required NotificationServicePort notificationService,
    required Task task,
    required int actualMinutes,
  }) async {
    await repository.complete(task.id, actualMinutes: actualMinutes);
    await notificationService.cancelTaskReminder(task.id);
  }

  Future<void> reopenTask({
    required TaskRepositoryPort repository,
    required NotificationServicePort notificationService,
    required Task task,
  }) async {
    await repository.reopen(task.id);
    await notificationService.scheduleTaskReminder(
      task.copyWith(status: TaskStatus.todo, clearActualMinutes: true, clearCompletedAt: true),
    );
  }

  Future<void> deleteTask({
    required TaskRepositoryPort repository,
    required NotificationServicePort notificationService,
    required Task task,
  }) async {
    await repository.delete(task.id);
    await notificationService.cancelTaskReminder(task.id);
  }
}
