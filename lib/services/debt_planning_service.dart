import 'dart:math';

import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';

class DebtPlanStatus {
  const DebtPlanStatus({
    required this.item,
    required this.earnedSinceCreated,
    required this.remainingDebt,
    required this.fundingGap,
    required this.daysLeft,
    required this.requiredDailyIncome,
    required this.requiredWorkMinutesPerDay,
    required this.progress,
    required this.message,
  });

  final DebtItem item;
  final int earnedSinceCreated;
  final int remainingDebt;
  final int fundingGap;
  final int daysLeft;
  final int requiredDailyIncome;
  final int requiredWorkMinutesPerDay;
  final double progress;
  final String message;
}

class DebtPlanningService {
  const DebtPlanningService();

  DebtPlanStatus statusFor(DebtItem item, FinanceRepository finance, {int? allocatedAmount}) {
    final now = DateTime.now();
    final endExclusive = item.dueAt.add(const Duration(days: 1));
    final earned = item.type == DebtType.debt
        ? finance.filtered(
            type: FinanceTransactionType.income,
            from: item.createdAt,
            to: endExclusive,
          ).fold<int>(0, (sum, t) => sum + t.amount)
        : 0;

    final remainingDebt = item.remainingAmount;
    final reserved = allocatedAmount;
    final fundingGap = item.type == DebtType.debt
        ? max(0, remainingDebt - (reserved ?? earned))
        : remainingDebt;
    final daysLeft = max(1, DateTime(item.dueAt.year, item.dueAt.month, item.dueAt.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays +
        1);
    final requiredDaily = (fundingGap / daysLeft).ceil();
    final hourly = finance.averageHourlyRate();
    final minutes = hourly <= 0 ? 0 : (requiredDaily / hourly * 60).ceil();
    final progress = item.amount <= 0 ? 0.0 : ((item.amount - remainingDebt) / item.amount).clamp(0, 1).toDouble();

    final message = _buildMessage(
      item: item,
      fundingGap: fundingGap,
      remainingDebt: remainingDebt,
      daysLeft: daysLeft,
      requiredDaily: requiredDaily,
      minutes: minutes,
      hourlyKnown: hourly > 0,
    );

    return DebtPlanStatus(
      item: item,
      earnedSinceCreated: earned,
      remainingDebt: remainingDebt,
      fundingGap: fundingGap,
      daysLeft: daysLeft,
      requiredDailyIncome: requiredDaily,
      requiredWorkMinutesPerDay: minutes,
      progress: progress,
      message: message,
    );
  }

  List<String> smartMessages(List<DebtItem> items, FinanceRepository finance) {
    return items.where((e) => e.isActive).map((e) => statusFor(e, finance).message).toList();
  }

  String _buildMessage({
    required DebtItem item,
    required int fundingGap,
    required int remainingDebt,
    required int daysLeft,
    required int requiredDaily,
    required int minutes,
    required bool hourlyKnown,
  }) {
    if (item.type == DebtType.receivable) {
      return 'از ${item.personName} ${PersianFormat.money(remainingDebt)} طلب داری؛ مهلت پیگیری ${PersianFormat.jalaliDate(item.dueAt)} است.';
    }

    if (remainingDebt <= 0) {
      return 'بدهی به ${item.personName} تسویه شده است.';
    }

    if (fundingGap <= 0) {
      return 'برای بدهی ${item.personName} به اندازه کافی درآمد جدید ثبت کرده‌ای؛ فقط پرداخت/تسویه را ثبت کن.';
    }

    if (!hourlyKnown) {
      return 'برای بدهی ${item.personName} تا ${PersianFormat.jalaliDate(item.dueAt)} باید روزانه حدود ${PersianFormat.money(requiredDaily)} کنار بگذاری. هنوز میانگین درآمد ساعتی ندارم.';
    }

    return 'برای بدهی ${item.personName} تا ${PersianFormat.jalaliDate(item.dueAt)} باید روزانه حدود ${PersianFormat.money(requiredDaily)} درآمد داشته باشی؛ با میانگین فعلی یعنی حدود ${PersianFormat.minutes(minutes)} کار درآمدزا در روز.';
  }
}
