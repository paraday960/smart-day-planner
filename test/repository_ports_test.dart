import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/domain/repositories/allocation_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/availability_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/category_budget_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/debt_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/finance_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/goal_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/planned_expense_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/task_repository_port.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/availability_repository.dart';
import 'package:smart_day_planner/services/category_budget_repository.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/task_repository.dart';

void main() {
  test('concrete repositories implement domain ports', () {
    expect(TaskRepository(), isA<TaskRepositoryPort>());
    expect(FinanceRepository(), isA<FinanceRepositoryPort>());
    expect(DebtRepository(), isA<DebtRepositoryPort>());
    expect(AllocationRepository(), isA<AllocationRepositoryPort>());
    expect(GoalRepository(), isA<GoalRepositoryPort>());
    expect(PlannedExpenseRepository(), isA<PlannedExpenseRepositoryPort>());
    expect(CategoryBudgetRepository(), isA<CategoryBudgetRepositoryPort>());
    expect(AvailabilityRepository(), isA<AvailabilityRepositoryPort>());
  });
}
