import '../models/debt_item.dart';
import '../utils/persian_format.dart';
import 'allocation_repository.dart';
import 'category_budget_repository.dart';
import 'debt_repository.dart';
import 'envelope_planning_service.dart';
import 'finance_repository.dart';
import 'planned_expense_repository.dart';

class SmartNotificationAdvisor {
  const SmartNotificationAdvisor({EnvelopePlanningService envelope = const EnvelopePlanningService()}) : _envelope = envelope;

  final EnvelopePlanningService _envelope;

  List<String> buildAlerts({
    required DebtRepository debts,
    required PlannedExpenseRepository plannedExpenses,
    required AllocationRepository allocations,
    required CategoryBudgetRepository budgets,
    required FinanceRepository finance,
  }) {
    final alerts = <String>[];
    final now = DateTime.now();

    for (final debt in debts.activeItems.where((d) => d.type == DebtType.debt)) {
      final remaining = _envelope.remainingForDebt(debt, allocations);
      final days = _daysLeft(debt.dueAt, now);
      if (remaining > 0 && days <= 2) {
        // برای بدهی عقب‌افتاده `days` صفر یا منفی است؛ پیام باید «مهلت گذشته» باشد.
        alerts.add(days <= 0
            ? 'هشدار: مهلت بدهی ${debt.personName} گذشته و هنوز ${PersianFormat.money(remaining)} کم داری.'
            : 'هشدار: فقط ${PersianFormat.digits(days)} روز تا بدهی ${debt.personName} مانده و ${PersianFormat.money(remaining)} کم داری.');
      }
    }

    for (final item in plannedExpenses.activeItems) {
      final remaining = _envelope.remainingForPlannedExpense(item, allocations);
      final days = _daysLeft(item.dueAt, now);
      if (remaining > 0 && days <= 3) {
        alerts.add(days <= 0
            ? 'هشدار: مهلت «${item.title}» گذشته و هنوز ${PersianFormat.money(remaining)} کم داری.'
            : 'هشدار: برای «${item.title}» ${PersianFormat.money(remaining)} کم داری و ${PersianFormat.digits(days)} روز مانده.');
      }
    }

    alerts.addAll(_envelope.budgetWarnings(budgets: budgets.items, financeRepository: finance));

    if (alerts.isEmpty) alerts.add('فعلاً هشدار فوری نداری.');
    return alerts.take(6).toList();
  }

  /// روزهای مانده تا مهلت (امروز = ۱). برای مهلت‌های گذشته صفر یا منفی برمی‌گردد
  /// و باید در پیام‌ها به‌عنوان «عقب‌افتاده» نمایش داده شود.
  int _daysLeft(DateTime dueAt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return due.difference(today).inDays + 1;
  }
}
