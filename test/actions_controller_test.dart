import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/application/actions/allocation_actions_controller.dart';
import 'package:smart_day_planner/application/actions/debt_actions_controller.dart';
import 'package:smart_day_planner/models/debt_item.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/money_allocation.dart';

void main() {
  group('DebtActionsController', () {
    test('builds expense transaction for debt payment', () {
      final controller = DebtActionsController();
      final debt = DebtItem(
        id: 'd1',
        type: DebtType.debt,
        personName: 'ممد',
        amount: 1000000,
        dueAt: DateTime(2026, 1, 2),
        createdAt: DateTime(2026, 1, 1),
      );

      final transaction = controller.buildSettlementTransaction(item: debt, amount: 500000);

      expect(transaction.type, FinanceTransactionType.expense);
      expect(transaction.amount, 500000);
      expect(transaction.category, 'بدهی');
    });

    test('builds income transaction for receivable collection', () {
      final controller = DebtActionsController();
      final receivable = DebtItem(
        id: 'r1',
        type: DebtType.receivable,
        personName: 'علی',
        amount: 2000000,
        dueAt: DateTime(2026, 1, 2),
        createdAt: DateTime(2026, 1, 1),
      );

      final transaction = controller.buildSettlementTransaction(item: receivable, amount: 1000000);

      expect(transaction.type, FinanceTransactionType.income);
      expect(transaction.amount, 1000000);
      expect(transaction.category, 'طلب');
    });
  });

  group('AllocationActionsController', () {
    test('builds allocation for debt envelope', () {
      final controller = AllocationActionsController();
      final allocation = controller.buildAllocation(
        targetType: AllocationTargetType.debt,
        targetId: 'd1',
        amount: 300000,
        note: 'پاکت بدهی ممد',
      );

      expect(allocation.targetType, AllocationTargetType.debt);
      expect(allocation.targetId, 'd1');
      expect(allocation.amount, 300000);
    });
  });
}
