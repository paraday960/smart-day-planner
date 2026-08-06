import 'dart:math';

import 'work_learning_service.dart';

/// یک بدهی برای محاسبهٔ برنامهٔ پرداخت.
class RepaymentDebt {
  const RepaymentDebt({
    required this.personName,
    required this.amount,
    required this.dueAt,
  });

  final String personName;
  final int amount;
  final DateTime dueAt;
}

/// یک بدهی با اولویت محاسبه‌شده.
class PrioritizedDebt {
  const PrioritizedDebt({
    required this.personName,
    required this.amount,
    required this.dueAt,
    required this.daysLeft,
    required this.rank,
  });

  final String personName;
  final int amount;
  final DateTime dueAt;

  /// روزهای مانده تا مهلت (حداقل ۱).
  final int daysLeft;

  /// رتبهٔ اولویت (۱ = اول).
  final int rank;
}

/// برنامهٔ پرداخت بدهی — نتیجهٔ «حل مسئله».
class RepaymentPlan {
  const RepaymentPlan({
    required this.totalRemaining,
    required this.priority,
    required this.horizonDays,
    required this.requiredDailyEarning,
    required this.requiredHoursPerDay,
    required this.feasible,
    required this.estimatedPayoffDate,
    required this.hasEnoughHistory,
  });

  /// مجموع بدهی‌های فعال.
  final int totalRemaining;

  /// بدهی‌ها به ترتیب اولویت پرداخت.
  final List<PrioritizedDebt> priority;

  /// روزهای در دسترس تا فوری‌ترین مهلت (افق پرداخت).
  final int horizonDays;

  /// درآمد لازم در روز (تومان) برای پرداخت همه تا مهلت.
  final int requiredDailyEarning;

  /// ساعت کار لازم در روز (با میانگین درآمد ساعتی کاربر).
  final double requiredHoursPerDay;

  /// آیا با توان کاربر در این افق شدنی است؟
  final bool feasible;

  /// تاریخ تخمینی پایان پرداخت‌ها با توان روزانهٔ یادگرفته‌شده.
  final DateTime? estimatedPayoffDate;

  /// آیا سابقهٔ کافی برای تخمین توان روزانه وجود دارد؟
  final bool hasEnoughHistory;

  String get horizonLabel => '${horizonDays} روز';

  String get requiredHoursLabel {
    if (requiredHoursPerDay <= 0) return 'نامشخص';
    final rounded = requiredHoursPerDay.toStringAsFixed(requiredHoursPerDay >= 10 ? 0 : 1);
    return '$rounded ساعت';
  }
}

/// موتور محاسبهٔ برنامهٔ پرداخت بدهی.
///
/// - مجموع بدهی‌ها را محاسبه می‌کند
/// - اولویت پرداخت را تعیین می‌کند (فوری‌ترین مهلت اول، سپس مبلغ بیشتر)
/// - درآمد و ساعت کار لازم در روز را حساب می‌کند
/// - با «توان روزانهٔ یادگرفته‌شده» (سابقهٔ کاربر) امکان‌سنجی و تاریخ
///   پایان تخمینی می‌دهد
class DebtRepaymentPlanner {
  const DebtRepaymentPlanner();

  /// حداکثر ساعت کاری معقول در روز (بالاتر از آن «غیرممکن» تلقی می‌شود).
  static const double maxReasonableHoursPerDay = 14;

  /// محاسبهٔ برنامهٔ پرداخت.
  RepaymentPlan plan({
    required List<RepaymentDebt> debts,
    required WorkProfile profile,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    if (debts.isEmpty) {
      return RepaymentPlan(
        totalRemaining: 0,
        priority: const [],
        horizonDays: 0,
        requiredDailyEarning: 0,
        requiredHoursPerDay: 0,
        feasible: true,
        estimatedPayoffDate: null,
        hasEnoughHistory: profile.hasEnoughData,
      );
    }

    // ── مجموع ──
    final total = debts.fold<int>(0, (sum, d) => sum + d.amount);

    // ── اولویت: فوری‌ترین مهلت اول، سپس مبلغ بیشتر ──
    final sorted = [...debts]..sort((a, b) {
        final byDate = a.dueAt.compareTo(b.dueAt);
        if (byDate != 0) return byDate;
        return b.amount.compareTo(a.amount);
      });

    final priority = <PrioritizedDebt>[];
    for (var i = 0; i < sorted.length; i++) {
      final debt = sorted[i];
      final daysLeft = max(
        1,
        DateTime(debt.dueAt.year, debt.dueAt.month, debt.dueAt.day)
            .difference(today)
            .inDays,
      );
      priority.add(PrioritizedDebt(
        personName: debt.personName,
        amount: debt.amount,
        dueAt: debt.dueAt,
        daysLeft: daysLeft,
        rank: i + 1,
      ));
    }

    // ── افق: فوری‌ترین مهلت ──
    final earliestDue = sorted.first.dueAt;
    final horizonDays = max(
      1,
      DateTime(earliestDue.year, earliestDue.month, earliestDue.day)
          .difference(today)
          .inDays,
    );

    // ── نیاز روزانه ──
    final requiredDaily = (total / horizonDays).ceil();
    final hourlyRate = profile.avgHourlyRate;
    final requiredHours = hourlyRate > 0 ? requiredDaily / hourlyRate : 0.0;

    // ── امکان‌سنجی با توان یادگرفته‌شده ──
    final capacity = profile.dailyEarningCapacity;
    final feasible =
        requiredHours > 0 && requiredHours <= maxReasonableHoursPerDay;

    // ── تاریخ پایان تخمینی با توان روزانه ──
    DateTime? payoffDate;
    if (capacity > 0 && profile.hasEnoughData) {
      final daysNeeded = (total / capacity).ceil();
      payoffDate = current.add(Duration(days: daysNeeded));
    }

    return RepaymentPlan(
      totalRemaining: total,
      priority: priority,
      horizonDays: horizonDays,
      requiredDailyEarning: requiredDaily,
      requiredHoursPerDay: requiredHours,
      feasible: feasible,
      estimatedPayoffDate: payoffDate,
      hasEnoughHistory: profile.hasEnoughData,
    );
  }
}
