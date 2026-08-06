import '../../models/planned_expense_goal.dart';

abstract class PlannedExpenseRepositoryPort {
  List<PlannedExpenseGoal> get items;
  List<PlannedExpenseGoal> get activeItems;

  Future<void> add(PlannedExpenseGoal item);
  Future<void> update(PlannedExpenseGoal item);
  Future<void> delete(String id);
  Future<void> markDone(String id);
  Future<void> replaceAll(List<PlannedExpenseGoal> items);
}
