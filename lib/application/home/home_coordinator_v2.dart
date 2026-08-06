import '../../domain/repositories/allocation_repository_port.dart';
import '../../domain/repositories/debt_repository_port.dart';
import '../../domain/repositories/finance_repository_port.dart';
import '../../domain/repositories/task_repository_port.dart';
import '../../models/debt_item.dart';
import '../../models/finance_transaction.dart';
import '../../models/money_allocation.dart';
import '../../models/task.dart';

/// نسخه آزمایشی Coordinator مبتنی بر Port/Interface.
/// هدف: تست‌پذیری بدون نیاز به SQLite، SharedPreferences یا سرویس‌های Flutter.
class HomeCoordinatorV2 {
  const HomeCoordinatorV2({
    required this.tasks,
    required this.finance,
    required this.debts,
    required this.allocations,
  });

  final TaskRepositoryPort tasks;
  final FinanceRepositoryPort finance;
  final DebtRepositoryPort debts;
  final AllocationRepositoryPort allocations;

  Future<void> saveTask(Task task, {required bool isNew}) async {
    if (isNew) {
      await tasks.add(task);
    } else {
      await tasks.update(task);
    }
  }

  Future<void> completeTask(Task task, {required int actualMinutes}) async {
    await tasks.complete(task.id, actualMinutes: actualMinutes);
  }

  Future<void> settleDebt(DebtItem item, int amount) async {
    if (amount <= 0) return;
    await debts.addPayment(item.id, amount);
    await finance.add(
      FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: item.type == DebtType.debt ? FinanceTransactionType.expense : FinanceTransactionType.income,
        amount: amount,
        createdAt: DateTime.now(),
        note: item.type == DebtType.debt ? 'پرداخت بدهی به ${item.personName}' : 'دریافت طلب از ${item.personName}',
        category: item.type == DebtType.debt ? 'بدهی' : 'طلب',
      ),
    );
  }

  Future<void> allocateMoney({
    required AllocationTargetType targetType,
    required String targetId,
    required int amount,
    required String note,
  }) async {
    if (amount <= 0) return;
    await allocations.add(
      MoneyAllocation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        targetType: targetType,
        targetId: targetId,
        amount: amount,
        createdAt: DateTime.now(),
        note: note,
      ),
    );
  }
}
