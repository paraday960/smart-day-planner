import '../../models/debt_item.dart';
import '../../models/finance_transaction.dart';
import '../../domain/repositories/debt_repository_port.dart';
import '../../domain/repositories/finance_repository_port.dart';

class DebtActionsController {
  const DebtActionsController();

  FinanceTransaction buildSettlementTransaction({
    required DebtItem item,
    required int amount,
  }) {
    return FinanceTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: item.type == DebtType.debt ? FinanceTransactionType.expense : FinanceTransactionType.income,
      amount: amount,
      createdAt: DateTime.now(),
      note: item.type == DebtType.debt ? 'پرداخت بدهی به ${item.personName}' : 'دریافت طلب از ${item.personName}',
      category: item.type == DebtType.debt ? 'بدهی' : 'طلب',
    );
  }

  Future<void> addDebt({
    required DebtRepositoryPort repository,
    required DebtItem item,
  }) async {
    await repository.add(item);
  }

  Future<void> settleAmount({
    required DebtRepositoryPort debtRepository,
    required FinanceRepositoryPort financeRepository,
    required DebtItem item,
    required int amount,
  }) async {
    if (amount <= 0) return;
    await debtRepository.addPayment(item.id, amount);
    await financeRepository.add(buildSettlementTransaction(item: item, amount: amount));
  }
}
