import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/home/home_coordinator_v2.dart';
import 'package:smart_day_planner/domain/repositories/allocation_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/debt_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/finance_repository_port.dart';
import 'package:smart_day_planner/domain/repositories/task_repository_port.dart';
import 'package:smart_day_planner/models/debt_item.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/money_allocation.dart';
import 'package:smart_day_planner/models/task.dart';

void main() {
  test('settleDebt records payment and creates expense transaction', () async {
    final debts = FakeDebtRepository();
    final finance = FakeFinanceRepository();
    final coordinator = HomeCoordinatorV2(
      tasks: FakeTaskRepository(),
      finance: finance,
      debts: debts,
      allocations: FakeAllocationRepository(),
    );
    final debt = DebtItem(
      id: 'd1',
      type: DebtType.debt,
      personName: 'ممد',
      amount: 1000000,
      dueAt: DateTime(2026, 1, 3),
      createdAt: DateTime(2026, 1, 1),
    );
    await debts.add(debt);

    await coordinator.settleDebt(debt, 400000);

    expect(debts.items.single.paidAmount, 400000);
    expect(finance.transactions.single.type, FinanceTransactionType.expense);
    expect(finance.transactions.single.amount, 400000);
  });

  test('allocateMoney adds allocation to fake repository', () async {
    final allocations = FakeAllocationRepository();
    final coordinator = HomeCoordinatorV2(
      tasks: FakeTaskRepository(),
      finance: FakeFinanceRepository(),
      debts: FakeDebtRepository(),
      allocations: allocations,
    );

    await coordinator.allocateMoney(
      targetType: AllocationTargetType.debt,
      targetId: 'd1',
      amount: 250000,
      note: 'پاکت بدهی',
    );

    expect(allocations.items.single.amount, 250000);
    expect(allocations.totalFor(AllocationTargetType.debt, 'd1'), 250000);
  });
}

class FakeTaskRepository implements TaskRepositoryPort {
  @override
  final List<Task> tasks = [];

  @override
  Future<void> add(Task task) async => tasks.add(task);

  @override
  Future<void> update(Task task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    tasks[index] = task;
  }

  @override
  Future<void> delete(String id) async => tasks.removeWhere((task) => task.id == id);

  @override
  Future<void> togglePin(String id) async {}

  @override
  Future<void> complete(String id, {required int actualMinutes}) async {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    tasks[index] = tasks[index].copyWith(status: TaskStatus.done, actualMinutes: actualMinutes, completedAt: DateTime.now());
  }

  @override
  Future<void> reopen(String id) async {}

  @override
  Future<void> replaceAll(List<Task> values) async {
    tasks..clear()..addAll(values);
  }
}

class FakeFinanceRepository implements FinanceRepositoryPort {
  @override
  final List<FinanceTransaction> transactions = [];

  @override
  Future<void> add(FinanceTransaction transaction) async => transactions.add(transaction);

  @override
  Future<void> delete(String id) async => transactions.removeWhere((transaction) => transaction.id == id);

  @override
  Future<void> replaceAll(List<FinanceTransaction> values) async {
    transactions..clear()..addAll(values);
  }
}

class FakeDebtRepository implements DebtRepositoryPort {
  @override
  final List<DebtItem> items = [];

  @override
  List<DebtItem> get activeItems => items.where((item) => item.isActive).toList();

  @override
  Future<void> add(DebtItem item) async => items.add(item);

  @override
  Future<void> update(DebtItem item) async {
    final index = items.indexWhere((value) => value.id == item.id);
    if (index == -1) return;
    items[index] = item;
  }

  @override
  Future<void> delete(String id) async => items.removeWhere((item) => item.id == id);

  @override
  Future<void> addPayment(String id, int amount) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = items[index];
    items[index] = item.copyWith(paidAmount: item.paidAmount + amount);
  }

  @override
  Future<void> markSettled(String id) async {}

  @override
  Future<void> replaceAll(List<DebtItem> values) async {
    items..clear()..addAll(values);
  }
}

class FakeAllocationRepository implements AllocationRepositoryPort {
  @override
  final List<MoneyAllocation> items = [];

  @override
  int totalFor(AllocationTargetType targetType, String targetId) {
    return items
        .where((item) => item.targetType == targetType && item.targetId == targetId)
        .fold(0, (sum, item) => sum + item.amount);
  }

  @override
  int totalAllocated() => items.fold(0, (sum, item) => sum + item.amount);

  @override
  Future<void> add(MoneyAllocation allocation) async => items.add(allocation);

  @override
  Future<void> delete(String id) async => items.removeWhere((item) => item.id == id);

  @override
  Future<void> replaceAll(List<MoneyAllocation> values) async {
    items..clear()..addAll(values);
  }
}

