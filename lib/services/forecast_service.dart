import 'dart:math';

import '../models/debt_item.dart';
import '../models/planned_expense_goal.dart';
import '../utils/persian_format.dart';
import 'allocation_repository.dart';
import 'debt_repository.dart';
import 'envelope_planning_service.dart';
import 'finance_repository.dart';
import 'planned_expense_repository.dart';

class ForecastService {
  const ForecastService({EnvelopePlanningService envelope = const EnvelopePlanningService()}) : _envelope = envelope;

  final EnvelopePlanningService _envelope;

  String noWorkTomorrowImpact({
    required DebtRepository debts,
    required PlannedExpenseRepository plannedExpenses,
    required AllocationRepository allocations,
  }) {
    final lines = <String>[];
    for (final debt in debts.activeItems.where((d) => d.type == DebtType.debt).take(3)) {
      final remaining = _envelope.remainingForDebt(debt, allocations);
      if (remaining <= 0) continue;
      final days = _daysLeft(debt.dueAt);
      final afterSkip = max(1, days - 1);
      final newDaily = (remaining / afterSkip).ceil();
      lines.add('اگر فردا برای بدهی ${debt.personName} پول کنار نگذاری، روزهای بعد باید حدود ${PersianFormat.money(newDaily)} در روز تأمین کنی.');
    }

    for (final plan in plannedExpenses.activeItems.take(3)) {
      final remaining = _envelope.remainingForPlannedExpense(plan, allocations);
      if (remaining <= 0) continue;
      final days = _daysLeft(plan.dueAt);
      final afterSkip = max(1, days - 1);
      final newDaily = (remaining / afterSkip).ceil();
      lines.add('برای «${plan.title}» اگر فردا کنار نگذاری، روزهای بعد حدود ${PersianFormat.money(newDaily)} در روز لازم می‌شود.');
    }

    if (lines.isEmpty) return 'فعلاً بدهی یا هزینه آینده فعالی نداری که با کار نکردن فردا به خطر بیفتد.';
    return lines.join('\n');
  }

  String workHoursImpact({
    required double hours,
    required FinanceRepository finance,
    required DebtRepository debts,
    required PlannedExpenseRepository plannedExpenses,
    required AllocationRepository allocations,
  }) {
    final hourly = finance.averageHourlyRate();
    if (hourly <= 0) return 'هنوز میانگین درآمد ساعتی ندارم؛ چند کار درآمدزا را با زمان واقعی ثبت کن تا بتوانم سناریو بسازم.';

    final expected = (hourly * hours).round();
    final suggestions = _envelope.allocationSuggestions(
      newIncome: expected,
      debts: debts.activeItems,
      plannedExpenses: plannedExpenses.activeItems,
      allocations: allocations,
    );

    return 'اگر امروز حدود ${PersianFormat.digits(hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1))} ساعت کار درآمدزا انجام بدهی، با میانگین فعلی حدود ${PersianFormat.money(expected)} درآمد احتمالی داری. پیشنهاد تخصیص:\n${suggestions.map((s) => '• $s').join('\n')}';
  }

  String riskSummary({
    required DebtRepository debts,
    required PlannedExpenseRepository plannedExpenses,
    required AllocationRepository allocations,
  }) {
    final risks = <String>[];
    for (final debt in debts.activeItems.where((d) => d.type == DebtType.debt)) {
      final remaining = _envelope.remainingForDebt(debt, allocations);
      final days = _daysLeft(debt.dueAt);
      if (remaining > 0 && days <= 2) {
        risks.add('ریسک بالا: بدهی ${debt.personName} فقط ${PersianFormat.digits(days)} روز وقت دارد و ${PersianFormat.money(remaining)} کم است.');
      }
    }
    for (final plan in plannedExpenses.activeItems) {
      final remaining = _envelope.remainingForPlannedExpense(plan, allocations);
      final days = _daysLeft(plan.dueAt);
      if (remaining > 0 && days <= 3) {
        risks.add('ریسک متوسط/بالا: برای «${plan.title}» ${PersianFormat.money(remaining)} کم داری و ${PersianFormat.digits(days)} روز مانده.');
      }
    }
    if (risks.isEmpty) return 'ریسک مالی فوری جدی نمی‌بینم.';
    return risks.take(5).join('\n');
  }

  int _daysLeft(DateTime dueAt) {
    final now = DateTime.now();
    return max(1, DateTime(dueAt.year, dueAt.month, dueAt.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays +
        1);
  }
}
