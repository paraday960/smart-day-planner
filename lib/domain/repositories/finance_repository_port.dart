import '../../models/finance_transaction.dart';

abstract class FinanceRepositoryPort {
  List<FinanceTransaction> get transactions;

  Future<void> add(FinanceTransaction transaction);
  Future<void> delete(String id);
  Future<void> replaceAll(List<FinanceTransaction> transactions);
}
