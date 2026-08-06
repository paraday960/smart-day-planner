import '../../models/money_allocation.dart';
import '../../domain/repositories/allocation_repository_port.dart';

class AllocationActionsController {
  const AllocationActionsController();

  MoneyAllocation buildAllocation({
    required AllocationTargetType targetType,
    required String targetId,
    required int amount,
    required String note,
  }) {
    return MoneyAllocation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      targetType: targetType,
      targetId: targetId,
      amount: amount,
      createdAt: DateTime.now(),
      note: note,
    );
  }

  Future<void> allocate({
    required AllocationRepositoryPort repository,
    required AllocationTargetType targetType,
    required String targetId,
    required int amount,
    required String note,
  }) async {
    if (amount <= 0) return;
    await repository.add(
      buildAllocation(
        targetType: targetType,
        targetId: targetId,
        amount: amount,
        note: note,
      ),
    );
  }
}
