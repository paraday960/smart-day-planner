import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/category_budget_repository.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/smart_notification_advisor.dart';

void main() {
  const advisor = SmartNotificationAdvisor();

  late FinanceRepository finance;
  late DebtRepository debts;
  late PlannedExpenseRepository plans;
  late AllocationRepository allocations;
  late CategoryBudgetRepository budgets;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    finance = FinanceRepository();
    debts = DebtRepository();
    plans = PlannedExpenseRepository();
    allocations = AllocationRepository();
    budgets = CategoryBudgetRepository();
    await Future.wait([
      finance.load(),
      debts.load(),
      plans.load(),
      allocations.load(),
      budgets.load(),
    ]);
  });

  FinanceTransaction _tx(String id, FinanceTransactionType type, int amount,
      int daysAgo) {
    return FinanceTransaction(
      id: id,
      type: type,
      amount: amount,
      category: 'عمومی',
      createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
    );
  }

  group('SmartNotificationAdvisor: هشدار دوام موجودی', () {
    test('وقتی موجودی تمام شده و هزینه‌ها بیشتر است → هشدار «تمام شده»', () async {
      // فقط یک هزینهٔ اخیر، بدون درآمد → موجودی منفی → runway صفر
      await finance.add(_tx('e1', FinanceTransactionType.expense, 100000, 2));
      final alerts = advisor.buildAlerts(
        debts: debts,
        plannedExpenses: plans,
        allocations: allocations,
        budgets: budgets,
        finance: finance,
      );
      expect(alerts.any((a) => a.contains('موجودی') && a.contains('تمام شده')),
          isTrue);
    });

    test('موجودی کم و ریتم سوزاندن سریع → هشدار چند روز دوام', () async {
      // درآمد قدیمی (بیرون از پنجرهٔ ۳۰ روز) موجودی را مثبت می‌کند،
      // ولی هزینهٔ اخیر سرعت سوزاندن را بالا می‌برد → دوام کوتاه.
      await finance
          .add(_tx('i1', FinanceTransactionType.income, 350000, 40));
      await finance
          .add(_tx('e1', FinanceTransactionType.expense, 300000, 5));
      final alerts = advisor.buildAlerts(
        debts: debts,
        plannedExpenses: plans,
        allocations: allocations,
        budgets: budgets,
        finance: finance,
      );
      expect(alerts.any((a) => a.contains('موجودی') && a.contains('تمام می‌شود')),
          isTrue);
    });

    test('درآمد کافی و بدون سوزاندن → هشدار دوام موجودی نمی‌آید', () async {
      await finance
          .add(_tx('i1', FinanceTransactionType.income, 1000000, 2));
      await finance.add(_tx('e1', FinanceTransactionType.expense, 100000, 1));
      final alerts = advisor.buildAlerts(
        debts: debts,
        plannedExpenses: plans,
        allocations: allocations,
        budgets: budgets,
        finance: finance,
      );
      expect(alerts.any((a) => a.contains('موجودی')), isFalse);
    });
  });
}
