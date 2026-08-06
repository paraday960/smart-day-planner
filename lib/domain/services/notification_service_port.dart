import '../../models/task.dart';

abstract class NotificationServicePort {
  Future<void> initialize();
  Future<void> scheduleTaskReminder(Task task);
  Future<void> cancelTaskReminder(String taskId);
  Future<void> scheduleSmartAlert({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });
}
