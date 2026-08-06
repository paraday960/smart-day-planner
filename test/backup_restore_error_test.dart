import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/backup_actions_controller.dart';

import 'fakes/fake_repositories.dart';

void main() {
  test('restoreBackup throws when passphrase is wrong', () async {
    final controller = BackupActionsController();
    final tasks = FakeTaskRepository();
    final finance = FakeFinanceRepository();
    final goals = FakeGoalRepository();
    final planned = FakePlannedExpenseRepository();
    final debts = FakeDebtRepository();
    final allocations = FakeAllocationRepository();
    final budgets = FakeCategoryBudgetRepository();

    final backup = controller.createBackup(
      taskRepository: tasks,
      financeRepository: finance,
      goalRepository: goals,
      plannedExpenseRepository: planned,
      debtRepository: debts,
      allocationRepository: allocations,
      categoryBudgetRepository: budgets,
      passphrase: 'correct-password',
    );

    await expectLater(
      controller.restoreBackup(
        encryptedBackup: backup,
        passphrase: 'wrong-password',
        taskRepository: FakeTaskRepository(),
        financeRepository: FakeFinanceRepository(),
        goalRepository: FakeGoalRepository(),
        plannedExpenseRepository: FakePlannedExpenseRepository(),
        debtRepository: FakeDebtRepository(),
        allocationRepository: FakeAllocationRepository(),
        categoryBudgetRepository: FakeCategoryBudgetRepository(),
      ),
      throwsA(anything),
    );
  });
}
