import '../../domain/repositories/allocation_repository_port.dart';
import '../../domain/repositories/category_budget_repository_port.dart';
import '../../domain/repositories/debt_repository_port.dart';
import '../../domain/repositories/finance_repository_port.dart';
import '../../domain/repositories/goal_repository_port.dart';
import '../../domain/repositories/planned_expense_repository_port.dart';
import '../../domain/repositories/task_repository_port.dart';
import '../../services/backup_service.dart';

class BackupActionsController {
  const BackupActionsController({BackupService backupService = const BackupService()}) : _backupService = backupService;

  final BackupService _backupService;

  String createBackup({
    required TaskRepositoryPort taskRepository,
    required FinanceRepositoryPort financeRepository,
    required GoalRepositoryPort goalRepository,
    required PlannedExpenseRepositoryPort plannedExpenseRepository,
    required DebtRepositoryPort debtRepository,
    required AllocationRepositoryPort allocationRepository,
    required CategoryBudgetRepositoryPort categoryBudgetRepository,
    required String passphrase,
  }) {
    return _backupService.createEncryptedBackup(
      tasks: taskRepository.tasks,
      transactions: financeRepository.transactions,
      dailyIncomeGoal: goalRepository.dailyIncomeGoal,
      monthlyIncomeGoal: goalRepository.monthlyIncomeGoal,
      dailyDeepWorkMinutes: goalRepository.dailyDeepWorkMinutes,
      plannedExpenses: plannedExpenseRepository.items,
      debts: debtRepository.items,
      allocations: allocationRepository.items,
      categoryBudgets: categoryBudgetRepository.items,
      passphrase: passphrase,
    );
  }

  Future<void> restoreBackup({
    required String encryptedBackup,
    required String passphrase,
    required TaskRepositoryPort taskRepository,
    required FinanceRepositoryPort financeRepository,
    required GoalRepositoryPort goalRepository,
    required PlannedExpenseRepositoryPort plannedExpenseRepository,
    required DebtRepositoryPort debtRepository,
    required AllocationRepositoryPort allocationRepository,
    required CategoryBudgetRepositoryPort categoryBudgetRepository,
  }) async {
    final restored = _backupService.restoreEncryptedBackup(
      encryptedBackup: encryptedBackup,
      passphrase: passphrase,
    );
    await taskRepository.replaceAll(restored.tasks);
    await financeRepository.replaceAll(restored.transactions);
    await plannedExpenseRepository.replaceAll(restored.plannedExpenses);
    await debtRepository.replaceAll(restored.debts);
    await allocationRepository.replaceAll(restored.allocations);
    await categoryBudgetRepository.replaceAll(restored.categoryBudgets);
    await goalRepository.setGoals(
      dailyIncomeGoal: restored.dailyIncomeGoal,
      monthlyIncomeGoal: restored.monthlyIncomeGoal,
      dailyDeepWorkMinutes: restored.dailyDeepWorkMinutes,
    );
  }
}
