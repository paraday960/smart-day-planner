import '../../models/debt_item.dart';

abstract class DebtRepositoryPort {
  List<DebtItem> get items;
  List<DebtItem> get activeItems;

  Future<void> add(DebtItem item);
  Future<void> update(DebtItem item);
  Future<void> delete(String id);
  Future<void> addPayment(String id, int amount);
  Future<void> markSettled(String id);
  Future<void> replaceAll(List<DebtItem> items);
}
