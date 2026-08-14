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

/// سرعت جریان نقدی (درآمد/هزینهٔ روزانهٔ میانگین) در یک بازه.
class CashFlowVelocity {
  const CashFlowVelocity({required this.dailyIncome, required this.dailyExpense});

  final int dailyIncome;
  final int dailyExpense;

  int get dailyNet => dailyIncome - dailyExpense;

  /// آیا در حال سوزاندن موجودی هستیم (هزینهٔ روزانه بیشتر از درآمد).
  bool get isBurn => dailyNet < 0;
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

  /// سرعت جریان نقدی در [days] روز اخیر (پیش‌فرض ۳۰ روز).
  CashFlowVelocity cashFlowVelocity(
    List<FinanceTransaction> transactions, {
    int days = 30,
    DateTime? now,
  }) {
    final range = _windowRange(days, now);
    var income = 0;
    var expense = 0;
    for (final t in transactions) {
      if (t.createdAt.isBefore(range.start) ||
          !t.createdAt.isBefore(range.end)) {
        continue;
      }
      if (t.type == FinanceTransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return CashFlowVelocity(
      dailyIncome: (income / days).round(),
      dailyExpense: (expense / days).round(),
    );
  }

  /// چند روزِ دیگر با این ریتم خرج کردن، موجودی فعلی دوام می‌آورد.
  ///
  /// null یعنی در حال سوزاندن موجودی نیستیم (درآمد ≥ هزینه). صفر یعنی
  /// موجودی تمام شده یا منفی است.
  int? runwayDays(
    List<FinanceTransaction> transactions, {
    int days = 30,
    DateTime? now,
  }) {
    final velocity = cashFlowVelocity(transactions, days: days, now: now);
    final burn = velocity.dailyExpense - velocity.dailyIncome;
    if (burn <= 0) return null;
    final balance =
        transactions.fold<int>(0, (sum, t) => sum + t.signedAmount);
    if (balance <= 0) return 0;
    return (balance / burn).floor();
  }

  /// نرخ پس‌انداز در [days] روز اخیر: (درآمد - هزینه) / درآمد.
  /// محدودهٔ [-2, 1]؛ منفی یعنی بیشتر از درآمد خرج شده.
  double savingsRate(
    List<FinanceTransaction> transactions, {
    int days = 30,
    DateTime? now,
  }) {
    final range = _windowRange(days, now);
    var income = 0;
    var expense = 0;
    for (final t in transactions) {
      if (t.createdAt.isBefore(range.start) ||
          !t.createdAt.isBefore(range.end)) {
        continue;
      }
      if (t.type == FinanceTransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    if (income <= 0) return 0;
    return ((income - expense) / income).clamp(-2.0, 1.0).toDouble();
  }

  /// ثبات درآمد: چه کسری از روزهای [days] روز اخیر حداقل یک درآمد ثبت شده.
  /// ۱ یعنی هر روز درآمد، نزدیک صفر یعنی درآمد پراکنده/نامنظم.
  double incomeRegularity(
    List<FinanceTransaction> transactions, {
    int days = 30,
    DateTime? now,
  }) {
    final range = _windowRange(days, now);
    final incomeDays = <DateTime>{};
    for (final t in transactions) {
      if (t.type != FinanceTransactionType.income) continue;
      if (t.createdAt.isBefore(range.start) ||
          !t.createdAt.isBefore(range.end)) {
        continue;
      }
      incomeDays.add(DateTime(
          t.createdAt.year, t.createdAt.month, t.createdAt.day));
    }
    if (days <= 0) return 0;
    return (incomeDays.length / days).clamp(0.0, 1.0).toDouble();
  }

  /// تحلیل عمیق‌تر جریان نقدی به‌صورت جمله‌های فارسی آمادهٔ نمایش.
  List<String> cashflowInsights(
    List<FinanceTransaction> transactions, {
    int days = 30,
    DateTime? now,
  }) {
    if (transactions.isEmpty) return const [];
    final velocity = cashFlowVelocity(transactions, days: days, now: now);
    final result = <String>[];

    if (velocity.dailyIncome > 0 || velocity.dailyExpense > 0) {
      result.add(
          'جریان نقدی ${PersianFormat.digits(days)} روز اخیر: روزانه حدود ${PersianFormat.money(velocity.dailyIncome)} درآمد و ${PersianFormat.money(velocity.dailyExpense)} هزینه (تراز روزانه ${PersianFormat.money(velocity.dailyNet)}).');
    }

    final runway = runwayDays(transactions, days: days, now: now);
    if (runway != null) {
      if (runway <= 0) {
        result.add(
            'موجودی‌ات تمام شده و هزینه‌ها بیشتر از درآمدند — همین امروز یک درآمد یا کاهش هزینه لازم داری.');
      } else {
        result.add(
            'با این ریتم خرج کردن، موجودی فعلی‌ات تا حدود ${PersianFormat.digits(runway)} روز دیگر دوام می‌آورد.');
      }
    }

    final rate = savingsRate(transactions, days: days, now: now);
    if (rate > 0.1) {
      result.add(
          'نرخ پس‌انداز ${PersianFormat.digits((rate * 100).round())}٪ است — بخشی از درآمدت باقی می‌ماند.');
    } else if (rate < 0) {
      result.add('نرخ پس‌انداز منفی است — بیشتر از درآمدت خرج می‌کنی.');
    }

    final regularity = incomeRegularity(transactions, days: days, now: now);
    if (regularity > 0 && regularity < 1) {
      final label = regularity >= 0.6
          ? 'نسبتاً منظم'
          : regularity >= 0.3
              ? 'نیمه‌منظم'
              : 'پراکنده';
      result.add(
          'درآمدت در ${PersianFormat.digits((regularity * 100).round())}٪ از روزها ثبت شده ($label).');
    }

    return result;
  }

  ({DateTime start, DateTime end}) _windowRange(int days, DateTime? now) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    return (
      start: today.subtract(Duration(days: days)),
      end: today.add(const Duration(days: 1)),
    );
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
