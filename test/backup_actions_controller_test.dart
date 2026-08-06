import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/backup_actions_controller.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/backup_service.dart';
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
    expect(decoded['format'], BackupService.backupFormatVersion);
    expect(decoded['salt'], isNotEmpty);
    expect(decoded['iv'], isNotEmpty);
    expect(decoded['iterations'], greaterThan(1000));
    expect(decoded['data'], isNotEmpty);
  });

  test('same passphrase produces different salt/iv each time', () {
    const controller = BackupActionsController();

    String makeBackup() => controller.createBackup(
          taskRepository: TaskRepository(),
          financeRepository: FinanceRepository(),
          goalRepository: GoalRepository(),
          plannedExpenseRepository: PlannedExpenseRepository(),
          debtRepository: DebtRepository(),
          allocationRepository: AllocationRepository(),
          categoryBudgetRepository: CategoryBudgetRepository(),
          passphrase: 'secret-123',
        );

    final first = jsonDecode(makeBackup()) as Map<String, dynamic>;
    final second = jsonDecode(makeBackup()) as Map<String, dynamic>;
    expect(first['salt'], isNot(second['salt']));
    expect(first['iv'], isNot(second['iv']));
    expect(first['data'], isNot(second['data']));
  });
}
