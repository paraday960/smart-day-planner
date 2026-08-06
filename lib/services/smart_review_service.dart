import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_insights_service.dart';

/// خلاصهٔ عملکرد یک روز.
class DayReview {
  const DayReview({
    required this.date,
    required this.tasksDone,
    required this.tasksLeft,
    required this.minutesWorked,
    required this.income,
    required this.expense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.focusScore,
  });

  final DateTime date;
  final int tasksDone;
  final int tasksLeft;
  final int minutesWorked;
  final int income;
  final int expense;
  final String? topCategory;
  final int topCategoryAmount;

  /// امتیاز تمرکز ۰ تا ۱۰۰ — نسبت کارهای تمام‌شده به کل کارهایِ امروز.
  final int focusScore;
}

/// خلاصهٔ عملکرد یک هفته.
class WeekReview {
  const WeekReview({
    required this.startDate,
    required this.endDate,
    required this.income,
    required this.expense,
    required this.tasksDone,
    required this.totalMinutesWorked,
    required this.avgDailyMinutes,
    required this.bestDay,
    required this.bestDayTasks,
    required this.topCategory,
    required this.anomalies,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int income;
  final int expense;
  final int tasksDone;
  final int totalMinutesWorked;
  final double avgDailyMinutes;
  final DateTime? bestDay;
  final int bestDayTasks;
  final String? topCategory;
  final List<ExpenseAnomaly> anomalies;
}

/// سرویس تولید گزارش‌های هوشمند روزانه/هفتگی — کاملاً pure و تست‌پذیر.
class SmartReviewService {
  const SmartReviewService();

  /// خلاصهٔ یک روز مشخص (پیش‌فرض: امروز).
  DayReview dayReview({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final day = DateTime(current.year, current.month, current.day);
    final next = day.add(const Duration(days: 1));

    final doneToday = tasks.where((t) {
      final c = t.completedAt;
      return t.isDone && c != null && !c.isBefore(day) && c.isBefore(next);
    }).toList();

    // کارهای «امروز»: ساخته‌شده یا با مهلت امروز و هنوز باز.
    final leftToday = tasks.where((t) {
      if (t.isDone) return false;
      final dueToday =
          t.dueAt != null && !t.dueAt!.isBefore(day) && t.dueAt!.isBefore(next);
      final createdToday =
          !t.createdAt.isBefore(day) && t.createdAt.isBefore(next);
      return dueToday || createdToday;
    }).toList();

    final minutes =
        doneToday.fold<int>(0, (sum, t) => sum + (t.actualMinutes ?? 0));

    final income =
        _total(transactions, FinanceTransactionType.income, day, next);
    final expense =
        _total(transactions, FinanceTransactionType.expense, day, next);

    final cats =
        _topCategory(transactions, FinanceTransactionType.expense, day, next);

    final totalToday = doneToday.length + leftToday.length;
    final focus = totalToday == 0
        ? (doneToday.isEmpty ? 0 : 100)
        : ((doneToday.length * 100) / totalToday).round().clamp(0, 100);

    return DayReview(
      date: day,
      tasksDone: doneToday.length,
      tasksLeft: leftToday.length,
      minutesWorked: minutes,
      income: income,
      expense: expense,
      topCategory: cats?.key,
      topCategoryAmount: cats?.value ?? 0,
      focusScore: focus,
    );
  }

  /// خلاصهٔ ۷ روز اخیر.
  WeekReview weekReview({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
    int days = 7,
  }) {
    final current = now ?? DateTime.now();
    final endDay = DateTime(current.year, current.month, current.day);
    final startDay = endDay.subtract(Duration(days: days - 1));
    final endNext = endDay.add(const Duration(days: 1));

    final income =
        _total(transactions, FinanceTransactionType.income, startDay, endNext);
    final expense =
        _total(transactions, FinanceTransactionType.expense, startDay, endNext);

    final done = tasks.where((t) {
      final c = t.completedAt;
      return t.isDone &&
          c != null &&
          !c.isBefore(startDay) &&
          c.isBefore(endNext);
    }).toList();
    final totalMinutes =
        done.fold<int>(0, (sum, t) => sum + (t.actualMinutes ?? 0));

    // بهترین روز (بیشترین کار تمام‌شده)
    final perDay = <DateTime, int>{};
    for (final t in done) {
      final d = DateTime(
          t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      perDay[d] = (perDay[d] ?? 0) + 1;
    }
    DateTime? bestDay;
    var bestCount = 0;
    perDay.forEach((d, count) {
      if (count > bestCount) {
        bestCount = count;
        bestDay = d;
      }
    });

    final cats = _topCategory(
        transactions, FinanceTransactionType.expense, startDay, endNext);

    final anomalies =
        const FinanceInsightsService().expenseAnomalies(transactions, days: 30);

    final workedDays = perDay.length;
    final avgDaily = workedDays == 0 ? 0.0 : totalMinutes / workedDays;

    return WeekReview(
      startDate: startDay,
      endDate: endDay,
      income: income,
      expense: expense,
      tasksDone: done.length,
      totalMinutesWorked: totalMinutes,
      avgDailyMinutes: avgDaily,
      bestDay: bestDay,
      bestDayTasks: bestCount,
      topCategory: cats?.key,
      anomalies: anomalies,
    );
  }

  /// متن فارسی خلاصهٔ روز.
  String daySummaryText({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final r = dayReview(tasks: tasks, transactions: transactions, now: now);
    final buffer = StringBuffer()
      ..writeln('خلاصهٔ امروز (${PersianFormat.jalaliDate(r.date)}):')
      ..writeln(
          '• ${PersianFormat.digits(r.tasksDone)} کار انجام شد، ${PersianFormat.digits(r.tasksLeft)} کار مانده.')
      ..writeln('• زمان واقعی کار: ${PersianFormat.minutes(r.minutesWorked)}.')
      ..writeln(
          '• درآمد: ${PersianFormat.money(r.income)} | هزینه: ${PersianFormat.money(r.expense)}.');
    if (r.topCategory != null && r.topCategoryAmount > 0) {
      buffer.writeln(
          '• بیشترین هزینه در «${r.topCategory}»: ${PersianFormat.money(r.topCategoryAmount)}.');
    }
    buffer.writeln(
        '• امتیاز تمرکز: ${PersianFormat.digits(r.focusScore)} از ۱۰۰.');
    if (r.focusScore >= 80) {
      buffer.write('عالی بود، به همین شکل ادامه بده! 🎯');
    } else if (r.focusScore >= 50) {
      buffer.write(
          'روز خوبی بود؛ میتوانی فردا چند کار کوچک اول صبح ببندی تا امتیاز بالاتر برود.');
    } else {
      buffer.write('روز شلوغی بود؛ فردا با ۲ کار کوچک شروع کن تا ریتم برگردد.');
    }
    return buffer.toString();
  }

  /// متن فارسی خلاصهٔ هفته.
  String weekSummaryText({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final r = weekReview(tasks: tasks, transactions: transactions, now: now);
    final buffer = StringBuffer()
      ..writeln(
          'خلاصهٔ هفته (${PersianFormat.jalaliDate(r.startDate)} تا ${PersianFormat.jalaliDate(r.endDate)}):')
      ..writeln(
          '• ${PersianFormat.digits(r.tasksDone)} کار انجام شد، جمعاً ${PersianFormat.minutes(r.totalMinutesWorked)}.')
      ..writeln(
          '• درآمد: ${PersianFormat.money(r.income)} | هزینه: ${PersianFormat.money(r.expense)}.')
      ..writeln(
          '• میانگین کار روزانه: ${PersianFormat.minutes(r.avgDailyMinutes.round())}.');
    if (r.bestDay != null) {
      buffer.writeln(
          '• بهترین روز: ${PersianFormat.jalaliDate(r.bestDay!)} با ${PersianFormat.digits(r.bestDayTasks)} کار.');
    }
    if (r.topCategory != null) {
      buffer.writeln('• بیشترین هزینه در «${r.topCategory}».');
    }
    if (r.anomalies.isNotEmpty) {
      final top = r.anomalies.first;
      buffer.writeln(
          '⚠️ هشدار: هزینهٔ «${top.category}» نسبت به ماه قبل ${_percent(top.increasePercent)} بیشتر شده.');
    }
    if (r.income > 0 && r.expense > r.income) {
      buffer.writeln(
          '⚠️ خرج هفته از درآمد بیشتر بوده؛ سعی کن هفتهٔ آینده یک دسته را کم کنی.');
    }
    return buffer.toString();
  }

  String _percent(double ratio) {
    if (ratio.isInfinite) return 'بسیار';
    return '${PersianFormat.digits(((ratio - 1) * 100).round())}٪';
  }

  int _total(
    List<FinanceTransaction> txs,
    FinanceTransactionType type,
    DateTime from,
    DateTime to,
  ) {
    return txs
        .where((t) =>
            t.type == type &&
            !t.createdAt.isBefore(from) &&
            t.createdAt.isBefore(to))
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  MapEntry<String, int>? _topCategory(
    List<FinanceTransaction> txs,
    FinanceTransactionType type,
    DateTime from,
    DateTime to,
  ) {
    final totals = <String, int>{};
    for (final t in txs) {
      if (t.type != type ||
          t.createdAt.isBefore(from) ||
          !t.createdAt.isBefore(to)) {
        continue;
      }
      totals.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    if (totals.isEmpty) return null;
    var best = totals.entries.first;
    for (final e in totals.entries) {
      if (e.value > best.value) best = e;
    }
    return best;
  }
}
