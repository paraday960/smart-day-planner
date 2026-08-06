import 'dart:math';

import '../models/finance_transaction.dart';
import '../models/planned_expense_goal.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';

class GoalPlanStatus {
  const GoalPlanStatus({
    required this.goal,
    required this.earnedSinceCreated,
    required this.remainingAmount,
    required this.daysLeft,
    required this.requiredDailyIncome,
    required this.requiredWorkMinutesPerDay,
    required this.progress,
    required this.message,
  });

  final PlannedExpenseGoal goal;
  final int earnedSinceCreated;
  final int remainingAmount;
  final int daysLeft;
  final int requiredDailyIncome;
  final int requiredWorkMinutesPerDay;
  final double progress;
  final String message;
}

class GoalPlanningService {
  const GoalPlanningService();

  GoalPlanStatus statusFor(PlannedExpenseGoal goal, FinanceRepository finance, {int? allocatedAmount}) {
    final now = DateTime.now();
    final endExclusive = goal.dueAt.add(const Duration(days: 1));
    final earned = finance.filtered(
      type: FinanceTransactionType.income,
      from: goal.createdAt,
      to: endExclusive,
    ).fold<int>(0, (sum, t) => sum + t.amount);

    final remaining = max(0, goal.targetAmount - (allocatedAmount ?? earned));
    final daysLeft = max(1, DateTime(goal.dueAt.year, goal.dueAt.month, goal.dueAt.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays +
        1);
    final requiredDaily = (remaining / daysLeft).ceil();
    final hourly = finance.averageHourlyRate();
    final minutes = hourly <= 0 ? 0 : (requiredDaily / hourly * 60).ceil();
    final progress = goal.targetAmount <= 0 ? 0.0 : (earned / goal.targetAmount).clamp(0, 1).toDouble();

    final message = remaining <= 0
        ? 'بودجه «${goal.title}» کامل تأمین شده است.'
        : hourly <= 0
            ? 'برای «${goal.title}» تا ${PersianFormat.jalaliDate(goal.dueAt)} باید روزانه حدود ${PersianFormat.money(requiredDaily)} کنار بگذاری. هنوز میانگین درآمد ساعتی برای تخمین زمان کار ندارم.'
            : 'برای «${goal.title}» تا ${PersianFormat.jalaliDate(goal.dueAt)} باید روزانه حدود ${PersianFormat.money(requiredDaily)} درآمد داشته باشی؛ با میانگین فعلی یعنی حدود ${PersianFormat.minutes(minutes)} کار درآمدزا در روز.';

    return GoalPlanStatus(
      goal: goal,
      earnedSinceCreated: earned,
      remainingAmount: remaining,
      daysLeft: daysLeft,
      requiredDailyIncome: requiredDaily,
      requiredWorkMinutesPerDay: minutes,
      progress: progress,
      message: message,
    );
  }

  List<String> smartMessages(List<PlannedExpenseGoal> goals, FinanceRepository finance) {
    return goals.where((g) => g.isActive).map((g) => statusFor(g, finance).message).toList();
  }
}
