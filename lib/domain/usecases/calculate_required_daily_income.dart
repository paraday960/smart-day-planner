import 'dart:math';

class RequiredDailyIncomeResult {
  const RequiredDailyIncomeResult({
    required this.remainingAmount,
    required this.daysLeft,
    required this.requiredDailyIncome,
  });

  final int remainingAmount;
  final int daysLeft;
  final int requiredDailyIncome;
}

class CalculateRequiredDailyIncome {
  const CalculateRequiredDailyIncome();

  RequiredDailyIncomeResult call({
    required int targetAmount,
    required int savedAmount,
    required DateTime dueAt,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final remaining = max(0, targetAmount - savedAmount);
    final days = max(1, DateTime(dueAt.year, dueAt.month, dueAt.day)
            .difference(DateTime(current.year, current.month, current.day))
            .inDays +
        1);
    return RequiredDailyIncomeResult(
      remainingAmount: remaining,
      daysLeft: days,
      requiredDailyIncome: (remaining / days).ceil(),
    );
  }
}
