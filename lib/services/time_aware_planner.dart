import '../models/scheduled_item.dart';
import '../models/task.dart';
import 'availability_repository.dart';
import 'smart_planner.dart';

class TimeAwarePlanner {
  const TimeAwarePlanner({SmartPlanner planner = const SmartPlanner()}) : _planner = planner;

  final SmartPlanner _planner;

  List<ScheduledItem> buildWorkWindowPlan({
    required List<Task> tasks,
    required WorkTimeSettings settings,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (settings.isOffDay(current)) return const [];

    final start = settings.workStartFor(current);
    final end = settings.workEndFor(current);
    final effectiveNow = current.isBefore(start) ? start : current;
    if (effectiveNow.isAfter(end)) return const [];

    final openTasks = tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) => _planner.priorityScore(b, now: current).compareTo(_planner.priorityScore(a, now: current)));

    var cursor = effectiveNow;
    final result = <ScheduledItem>[];
    for (final task in openTasks) {
      final minutes = _planner.recommendedEstimate(task, tasks);
      final finish = cursor.add(Duration(minutes: minutes));
      if (finish.isAfter(end)) continue;
      result.add(ScheduledItem(
        task: task,
        start: cursor,
        end: finish,
        priorityScore: _planner.priorityScore(task, now: current),
        reason: _planner.explainPriority(task, now: current),
      ));
      cursor = finish.add(Duration(minutes: settings.breakMinutesPerHour));
      if (cursor.isAfter(end)) break;
    }
    return result;
  }
}
