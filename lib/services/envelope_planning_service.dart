import 'dart:math';

import '../models/category_budget.dart';
import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/money_allocation.dart';
import '../models/planned_expense_goal.dart';
import '../utils/persian_format.dart';
import 'allocation_repository.dart';
import 'finance_repository.dart';

class EnvelopePlanningService {
  const EnvelopePlanningService();

  int allocatedForDebt(DebtItem item, AllocationRepository allocations) {
    return allocations.totalFor(AllocationTargetType.debt, item.id);
  }

  int allocatedForPlannedExpense(PlannedExpenseGoal item, AllocationRepository allocations) {
    return allocations.totalFor(AllocationTargetType.plannedExpense, item.id);
  }

  int remainingForDebt(DebtItem item, AllocationRepository allocations) {
    return max(0, item.remainingAmount - allocatedForDebt(item, allocations));
  }

  int remainingForPlannedExpense(PlannedExpenseGoal item, AllocationRepository allocations) {
    return max(0, item.targetAmount - allocatedForPlannedExpense(item, allocations));
  }

  List<String> allocationSuggestions({
    required int newIncome,
    required List<DebtItem> debts,
    required List<PlannedExpenseGoal> plannedExpenses,
    required AllocationRepository allocations,
  }) {
    var remainingIncome = newIncome;
    final result = <String>[];

    final urgentDebts = debts.where((d) => d.isActive && d.type == DebtType.debt).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    for (final debt in urgentDebts) {
      if (remainingIncome <= 0) break;
      final need = remainingForDebt(debt, allocations);
      if (need <= 0) continue;
      final suggested = min(remainingIncome, need);
      result.add('${PersianFormat.money(suggested)} برای بدهی ${debt.personName} کنار بگذار.');
      remainingIncome -= suggested;
    }

    final urgentPlans = plannedExpenses.where((p) => p.isActive).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    for (final plan in urgentPlans) {
      if (remainingIncome <= 0) break;
      final need = remainingForPlannedExpense(plan, allocations);
      if (need <= 0) continue;
      final suggested = min(remainingIncome, need);
      result.add('${PersianFormat.money(suggested)} برای «${plan.title}» کنار بگذار.');
      remainingIncome -= suggested;
    }

    if (remainingIncome > 0) {
      result.add('${PersianFormat.money(remainingIncome)} فعلاً آزاد می‌ماند یا می‌تواند برای پس‌انداز کنار گذاشته شود.');
    }

    if (result.isEmpty) result.add('فعلاً بدهی یا هزینه آینده‌ای برای تخصیص این درآمد پیدا نکردم.');
    return result;
  }

  List<String> budgetWarnings({
    required List<CategoryBudget> budgets,
    required FinanceRepository financeRepository,
  }) {
    final start = financeRepository.currentJalaliMonthStart();
    final end = financeRepository.currentJalaliMonthEnd();
    final result = <String>[];

    for (final budget in budgets) {
      final spent = financeRepository
          .filtered(type: FinanceTransactionType.expense, from: start, to: end)
          .where((t) => t.category == budget.category)
          .fold<int>(0, (sum, t) => sum + t.amount);
      if (budget.monthlyLimit <= 0) continue;
      final percent = spent / budget.monthlyLimit;
      if (percent >= 1) {
        result.add('بودجه «${budget.category}» تمام شده؛ ${PersianFormat.money(spent - budget.monthlyLimit)} بیشتر از حد خرج کرده‌ای.');
      } else if (percent >= 0.8) {
        result.add('بودجه «${budget.category}» به ${PersianFormat.digits((percent * 100).round())}٪ رسیده؛ مراقب خرج‌های بعدی باش.');
      }
    }

    return result;
  }
}
