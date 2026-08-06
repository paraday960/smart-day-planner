import '../models/finance_transaction.dart';
import '../utils/persian_format.dart';

/// یک هزینهٔ غیرعادی (نسبت به بازهٔ قبلی).
class ExpenseAnomaly {
  const ExpenseAnomaly({
    required this.category,
    required this.currentAmount,
    required this.previousAmount,
  });

  final String category;
  final int currentAmount;
  final int previousAmount;

  double get increasePercent =>
      previousAmount <= 0 ? double.infinity : currentAmount / previousAmount;
}

/// سرویس تحلیل مالی ساده برای دستیار هوشمند.
///
/// کاملاً pure است (ورودی لیست تراکنش‌ها) تا در تست‌ها بدون دیتابیس
/// قابل استفاده باشد.
class FinanceInsightsService {
  const FinanceInsightsService();

  static const int _anomalyDays = 30;
  static const double _anomalyThreshold = 1.5;
  static const int _minMeaningfulAnomaly = 100000; // تومان

  /// هزینه‌های غیرعادی: دسته‌هایی که در ۳۰ روز اخیر بیش از
  /// [threshold] برابرِ میانگین ۳۰ روز قبل شده‌اند.
  List<ExpenseAnomaly> expenseAnomalies(
    List<FinanceTransaction> transactions, {
    int days = _anomalyDays,
    double threshold = _anomalyThreshold,
  }) {
    if (transactions.isEmpty) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentStart = today.subtract(Duration(days: days));
    final previousStart = currentStart.subtract(Duration(days: days));

    final current = _totalsByCategory(
        transactions, FinanceTransactionType.expense,
        from: currentStart, to: today);
    final previous = _totalsByCategory(
        transactions, FinanceTransactionType.expense,
        from: previousStart, to: currentStart);

    final result = <ExpenseAnomaly>[];
    for (final entry in current.entries) {
      final prevAmount = previous[entry.key] ?? 0;
      if (prevAmount <= 0) continue;
      if (entry.value >= prevAmount * threshold &&
          entry.value - prevAmount >= _minMeaningfulAnomaly) {
        result.add(ExpenseAnomaly(
          category: entry.key,
          currentAmount: entry.value,
          previousAmount: prevAmount,
        ));
      }
    }
    result.sort((a, b) => b.increasePercent.compareTo(a.increasePercent));
    return result;
  }

  /// توصیه‌های مالی ساده بر اساس تراکنش‌ها.
  List<String> advice(List<FinanceTransaction> transactions) {
    if (transactions.isEmpty) return const [];

    final result = <String>[];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 30));
    final income = transactions
        .where((t) =>
            t.type == FinanceTransactionType.income &&
            !t.createdAt.isBefore(monthStart))
        .fold<int>(0, (sum, t) => sum + t.amount);
    final expense = transactions
        .where((t) =>
            t.type == FinanceTransactionType.expense &&
            !t.createdAt.isBefore(monthStart))
        .fold<int>(0, (sum, t) => sum + t.amount);

    if (income > 0 && expense > 0) {
      final rate = (expense / income).clamp(0, 10);
      if (rate > 0.9) {
        result.add(
            '۳۰ روز اخیر تقریباً همهٔ درآمدت خرج شده؛ بهتر است یک دستهٔ هزینه را کم کنی.');
      } else if (rate > 0.7) {
        result.add(
            'حدود ${PersianFormat.digits((rate * 100).round())}٪ درآمدت خرج شده؛ اگر پس‌انداز هدف داری، سعی کن به زیر ۷۰٪ برسد.');
      } else {
        result.add(
            'نسبت خرج به درآمد حدود ${PersianFormat.digits((rate * 100).round())}٪ است؛ روندت خوب است.');
      }
    }

    final anomalies = expenseAnomalies(transactions);
    if (anomalies.isNotEmpty) {
      final top = anomalies.first;
      result.add(
          'هشدار: هزینهٔ «${top.category}» نسبت به ماه قبل ${_percent(top.increasePercent)} بیشتر شده (${PersianFormat.money(top.currentAmount)}).');
    }

    final paidWorks = transactions.where((t) => t.hourlyRate != null).toList();
    if (paidWorks.length >= 2) {
      final totalMinutes =
          paidWorks.fold<int>(0, (sum, t) => sum + (t.minutesWorked ?? 0));
      final totalIncome = paidWorks.fold<int>(0, (sum, t) => sum + t.amount);
      if (totalMinutes > 0) {
        final hourly = totalIncome / totalMinutes * 60;
        result.add(
            'میانگین درآمد ساعتی: حدود ${PersianFormat.money(hourly.round())}.');
      }
    }

    return result;
  }

  /// یک جملهٔ ریسک مالی (یا null اگر ریسکی نباشد).
  String? riskFrom(List<FinanceTransaction> transactions) {
    if (transactions.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = today.subtract(const Duration(days: 30));
    final income = transactions
        .where((t) =>
            t.type == FinanceTransactionType.income &&
            !t.createdAt.isBefore(monthStart))
        .fold<int>(0, (sum, t) => sum + t.amount);
    final expense = transactions
        .where((t) =>
            t.type == FinanceTransactionType.expense &&
            !t.createdAt.isBefore(monthStart))
        .fold<int>(0, (sum, t) => sum + t.amount);

    if (expense > 0 && income == 0) {
      return 'در ۳۰ روز اخیر بدون درآمد، ${PersianFormat.money(expense)} هزینه شده.';
    }
    if (expense > income && income > 0) {
      final deficit = expense - income;
      return 'کسر بودجهٔ ۳۰ روز اخیر: ${PersianFormat.money(deficit)}.';
    }
    return null;
  }

  String _percent(double ratio) {
    if (ratio.isInfinite) return 'بسیار';
    final pct = ((ratio - 1) * 100).round();
    return '${PersianFormat.digits(pct)}٪';
  }

  Map<String, int> _totalsByCategory(
    List<FinanceTransaction> transactions,
    FinanceTransactionType type, {
    required DateTime from,
    required DateTime to,
  }) {
    final result = <String, int>{};
    for (final transaction in transactions) {
      if (transaction.type != type) continue;
      if (transaction.createdAt.isBefore(from) ||
          !transaction.createdAt.isBefore(to)) {
        continue;
      }
      result.update(transaction.category, (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount);
    }
    return result;
  }
}
