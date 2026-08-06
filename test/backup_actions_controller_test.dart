import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/backup_actions_controller.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/category_budget_repository.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/task_repository.dart';

void main() {
  test('createBackup returns encrypted backup wrapper', () {
    const controller = BackupActionsController();

    final backup = controller.createBackup(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      plannedExpenseRepository: PlannedExpenseRepository(),
      debtRepository: DebtRepository(),
      allocationRepository: AllocationRepository(),
      categoryBudgetRepository: CategoryBudgetRepository(),
      passphrase: 'secret-123',
    );

    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    expect(decoded['type'], 'smart_day_planner_encrypted_backup');
    expect(decoded['iv'], isNotEmpty);
    expect(decoded['data'], isNotEmpty);
  });
}
