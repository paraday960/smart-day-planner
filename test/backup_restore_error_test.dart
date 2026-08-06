import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/backup_actions_controller.dart';

import 'fakes/fake_repositories.dart';

void main() {
  test('restoreBackup throws when passphrase is wrong', () async {
    const controller = BackupActionsController();
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

  test('restoreBackup detects tampered backup (AES-GCM authenticity)', () async {
    const controller = BackupActionsController();

    final backup = controller.createBackup(
      taskRepository: FakeTaskRepository(),
      financeRepository: FakeFinanceRepository(),
      goalRepository: FakeGoalRepository(),
      plannedExpenseRepository: FakePlannedExpenseRepository(),
      debtRepository: FakeDebtRepository(),
      allocationRepository: FakeAllocationRepository(),
      categoryBudgetRepository: FakeCategoryBudgetRepository(),
      passphrase: 'correct-password',
    );

    // تغییر یک بایت از محتوای رمزنگاری‌شده → GCM باید خطا بدهد
    final wrapper = jsonDecode(backup) as Map<String, dynamic>;
    final data = base64Decode(wrapper['data'] as String);
    data[0] = (data[0] ^ 0xFF);
    wrapper['data'] = base64Encode(data);
    final tampered = jsonEncode(wrapper);

    await expectLater(
      controller.restoreBackup(
        encryptedBackup: tampered,
        passphrase: 'correct-password',
        taskRepository: FakeTaskRepository(),
        financeRepository: FakeFinanceRepository(),
        goalRepository: FakeGoalRepository(),
        plannedExpenseRepository: FakePlannedExpenseRepository(),
        debtRepository: FakeDebtRepository(),
        allocationRepository: FakeAllocationRepository(),
        categoryBudgetRepository: FakeCategoryBudgetRepository(),
      ),
      throwsArgumentError,
    );
  });
}
