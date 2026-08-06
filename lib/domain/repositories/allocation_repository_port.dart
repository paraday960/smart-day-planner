import '../../models/money_allocation.dart';

abstract class AllocationRepositoryPort {
  List<MoneyAllocation> get items;

  int totalFor(AllocationTargetType targetType, String targetId);
  int totalAllocated();
  Future<void> add(MoneyAllocation allocation);
  Future<void> delete(String id);
  Future<void> replaceAll(List<MoneyAllocation> items);
}
