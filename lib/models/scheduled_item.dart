import 'task.dart';

class ScheduledItem {
  const ScheduledItem({
    required this.task,
    required this.start,
    required this.end,
    required this.priorityScore,
    required this.reason,
  });

  final Task task;
  final DateTime start;
  final DateTime end;
  final int priorityScore;
  final String reason;
}
