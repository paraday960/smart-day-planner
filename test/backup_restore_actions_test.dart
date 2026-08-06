import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/backup_actions_controller.dart';
import 'package:smart_day_planner/models/debt_item.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';

import 'fakes/fake_repositories.dart';

void main() {
  test('backup can be restored into empty fake repositories', () async {
    final sourceTasks = FakeTaskRepository();
    final sourceFinance = FakeFinanceRepository();
    final sourceGoals = FakeGoalRepository();
    final sourcePlanned = FakePlannedExpenseRepository();
    final sourceDebts = FakeDebtRepository();
    final sourceAllocations = FakeAllocationRepository();
    final sourceBudgets = FakeCategoryBudgetRepository();

    await sourceTasks.add(Task(id: 't1', title: 'کار تست', createdAt: DateTime(2026, 1, 1)));
    await sourceFinance.add(FinanceTransaction(
      id: 'f1',
      type: FinanceTransactionType.income,
      amount: 1000000,
      createdAt: DateTime(2026, 1, 1),
    ));
    await sourceDebts.add(DebtItem(
      id: 'd1',
      type: DebtType.debt,
      personName: 'ممد',
      amount: 500000,
      dueAt: DateTime(2026, 1, 2),
      createdAt: DateTime(2026, 1, 1),
    ));
    await sourceGoals.setGoals(dailyIncomeGoal: 1000000, monthlyIncomeGoal: 20000000, dailyDeepWorkMinutes: 120);

    final controller = BackupActionsController();
    final backup = controller.createBackup(
      taskRepository: sourceTasks,
      financeRepository: sourceFinance,
      goalRepository: sourceGoals,
      plannedExpenseRepository: sourcePlanned,
      debtRepository: sourceDebts,
      allocationRepository: sourceAllocations,
      categoryBudgetRepository: sourceBudgets,
      passphrase: 'secret-123',
    );

    final targetTasks = FakeTaskRepository();
    final targetFinance = FakeFinanceRepository();
    final targetGoals = FakeGoalRepository();
    final targetPlanned = FakePlannedExpenseRepository();
    final targetDebts = FakeDebtRepository();
    final targetAllocations = FakeAllocationRepository();
    final targetBudgets = FakeCategoryBudgetRepository();

    await controller.restoreBackup(
      encryptedBackup: backup,
      passphrase: 'secret-123',
      taskRepository: targetTasks,
      financeRepository: targetFinance,
      goalRepository: targetGoals,
      plannedExpenseRepository: targetPlanned,
      debtRepository: targetDebts,
      allocationRepository: targetAllocations,
      categoryBudgetRepository: targetBudgets,
    );

    expect(targetTasks.tasks.single.title, 'کار تست');
    expect(targetFinance.transactions.single.amount, 1000000);
    expect(targetDebts.items.single.personName, 'ممد');
    expect(targetGoals.dailyIncomeGoal, 1000000);
  });
}
