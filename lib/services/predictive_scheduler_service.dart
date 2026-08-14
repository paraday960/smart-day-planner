import 'dart:math';
import '../models/task.dart';
import '../models/finance_transaction.dart';
import '../utils/persian_format.dart';
import 'advanced_habit_learning_service.dart';

/// 🔮 موتور پیش‌بینی و زمان‌بندی خودکار
/// با رگرسیون خطی ساده + یادگیری از روند

class ForecastPoint {
  const ForecastPoint({required this.date, required this.predictedValue, required this.confidence});
  final DateTime date;
  final int predictedValue;
  /// ۰-۱
  final double confidence;
}

class ScheduledTaskSuggestion {
  const ScheduledTaskSuggestion({
    required this.task,
    required this.suggestedStart,
    required this.reason,
    required this.priority,
  });
  final Task task;
  final DateTime suggestedStart;
  final String reason;
  final int priority;
}

/// پیش‌بینی هفتهٔ آینده: عملکرد (کارهای تکمیل‌شده) + مالی (درآمد/هزینه).
class WeeklyForecast {
  const WeeklyForecast({
    required this.projectedCompletedTasks,
    required this.projectedIncome,
    required this.projectedExpense,
    required this.confidence,
    required this.hasEnoughData,
  });

  /// تعداد کارهایی که احتمالاً هفتهٔ آینده تکمیل می‌شوند.
  final int projectedCompletedTasks;

  /// درآمد پیش‌بینی‌شدهٔ هفتهٔ آینده.
  final int projectedIncome;

  /// هزینهٔ پیش‌بینی‌شدهٔ هفتهٔ آینده.
  final int projectedExpense;

  /// اطمینان ۰ تا ۱.
  final double confidence;

  /// آیا دادهٔ کافی برای پیش‌بینی وجود دارد؟
  final bool hasEnoughData;

  int get projectedNet => projectedIncome - projectedExpense;
}

class PredictiveSchedulerService {
  const PredictiveSchedulerService();

  /// پیش‌بینی هفتهٔ آینده: تعداد کارهای تکمیل‌شده + درآمد/هزینه.
  ///
  /// تعداد کارها با میانگین موزون ۳ هفتهٔ اخیر برآورد می‌شود و مالی با
  /// همان رگرسیون خطی [forecast30Days] (۷ روز اول). بدون دادهٔ کافی
  /// `hasEnoughData=false` و اعداد صفر برمی‌گردد.
  WeeklyForecast weeklyForecast({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    // تعداد کارهای تکمیل‌شده در ۳ هفتهٔ اخیر. ایندکس ۰ باید «هفتهٔ اخیر» باشد
    // تا وزن‌دهی درست کار کند (قبلاً از قدیمی‌ترین هفته شروع می‌شد و وزن
    // هفتهٔ اخیر به قدیمی‌ترین هفته می‌خورد).
    final completedWeeks = <int>[];
    for (var i = 0; i < 3; i++) {
      final end = current.subtract(Duration(days: i * 7));
      final start = current.subtract(Duration(days: (i + 1) * 7));
      completedWeeks.add(tasks
          .where((t) =>
              t.isDone &&
              t.completedAt != null &&
              t.completedAt!.isAfter(start) &&
              !t.completedAt!.isAfter(end))
          .length);
    }

    final hasTaskHistory = completedWeeks.any((c) => c > 0);
    var projectedTasks = 0;
    if (hasTaskHistory) {
      final weighted =
          (completedWeeks[0] * 3 + completedWeeks[1] * 2 + completedWeeks[2]) /
              6.0;
      projectedTasks = weighted.round();
    }

    // مالی: مجموع ۷ روز اول پیش‌بینی ۳۰ روزه
    final projectedIncome = forecast30Days(
            transactions: transactions,
            type: FinanceTransactionType.income,
            now: current)
        .take(7)
        .fold<int>(0, (sum, p) => sum + p.predictedValue);
    final projectedExpense = forecast30Days(
            transactions: transactions,
            type: FinanceTransactionType.expense,
            now: current)
        .take(7)
        .fold<int>(0, (sum, p) => sum + p.predictedValue);

    final hasFinanceData = transactions.isNotEmpty;
    final hasEnoughData = hasTaskHistory || hasFinanceData;
    final confidence = !hasEnoughData
        ? 0.0
        : (hasTaskHistory && hasFinanceData)
            ? 0.7
            : 0.45;

    return WeeklyForecast(
      projectedCompletedTasks: projectedTasks,
      projectedIncome: projectedIncome,
      projectedExpense: projectedExpense,
      confidence: confidence,
      hasEnoughData: hasEnoughData,
    );
  }

  /// جمله‌های فارسی آمادهٔ نمایش برای هفتهٔ آینده.
  List<String> weeklyOutlook({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final forecast =
        weeklyForecast(tasks: tasks, transactions: transactions, now: now);
    if (!forecast.hasEnoughData) {
      return const [
        'هنوز دادهٔ کافی برای پیش‌بینی هفتهٔ آینده ندارم؛ چند روز کار و تراکنش ثبت کن.'
      ];
    }
    final result = <String>[];
    if (forecast.projectedCompletedTasks > 0) {
      result.add(
          'هفتهٔ آینده احتمالاً حدود ${PersianFormat.digits(forecast.projectedCompletedTasks)} کار کامل می‌کنی.');
    }
    if (forecast.projectedIncome > 0 || forecast.projectedExpense > 0) {
      result.add(
          'مالی هفتهٔ آینده: حدود ${PersianFormat.money(forecast.projectedIncome)} درآمد و ${PersianFormat.money(forecast.projectedExpense)} هزینه پیش‌بینی می‌شود (تراز ${PersianFormat.money(forecast.projectedNet)}).');
      if (forecast.projectedNet < 0) {
        result.add('هفتهٔ آینده کسری پیش‌بینی می‌شود — از الان فکری برایش بکن.');
      }
    }
    return result;
  }

  /// پیش‌بینی ۳۰ روز آینده هزینه/درآمد با رگرسیون خطی
  List<ForecastPoint> forecast30Days({
    required List<FinanceTransaction> transactions,
    required FinanceTransactionType type,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    // داده ۶۰ روز اخیر روزانه
    final daily = _dailyTotals(transactions, type, days: 60, now: current);
    if (daily.length < 7) {
      // داده کم → میانگین ساده
      final avg = daily.isEmpty ? 0 : daily.reduce((a,b) => a+b) ~/ max(1, daily.length);
      return List.generate(30, (i) {
        final date = current.add(Duration(days: i+1));
        return ForecastPoint(date: date, predictedValue: avg, confidence: 0.4);
      });
    }

    // رگرسیون خطی ساده: y = a + b*x
    final n = daily.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (var i = 0; i < n; i++) {
      sumX += i;
      sumY += daily[i];
      sumXY += i * daily[i];
      sumX2 += i * i;
    }
    final b = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final a = (sumY - b * sumX) / n;

    // واریانس برای confidence
    double variance = 0;
    for (var i = 0; i < n; i++) {
      final pred = a + b * i;
      variance += pow(daily[i] - pred, 2);
    }
    variance /= n;
    final std = sqrt(variance);
    final mean = sumY / n;
    // clamp روی double، نوع num برمی‌گرداند؛ صریحاً به double تبدیل می‌کنیم.
    final double confidence =
        mean == 0 ? 0.5 : (1 - (std / (mean + 1))).clamp(0.3, 0.9).toDouble();

    return List.generate(30, (i) {
      final x = n + i;
      var pred = (a + b * x).round();
      if (pred < 0) pred = 0;
      // هموارسازی با میانگین ۷ روز اخیر
      final recentAvg = daily.sublist(max(0, n-7)).reduce((a,b) => a+b) ~/ min(7, n);
      pred = (pred * 0.7 + recentAvg * 0.3).round();
      final date = current.add(Duration(days: i+1));
      return ForecastPoint(date: date, predictedValue: pred, confidence: confidence);
    });
  }

  /// زمان‌بندی خودکار هوشمند — بهترین ساعت برای هر کار
  List<ScheduledTaskSuggestion> autoSchedule({
    required List<Task> tasks,
    required AdvancedHabitProfile habitProfile,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) return [];

    // امتیازدهی ترکیبی: اولویت اصلی + تطابق با عادت
    final scored = <ScheduledTaskSuggestion>[];
    for (final task in open) {
      var score = 0;
      // اهمیت
      score += task.importance * 10;
      // عقب‌افتاده
      if (task.isOverdue) score += 50;
      else if (task.dueAt != null) {
        final hoursLeft = task.dueAt!.difference(current).inHours;
        if (hoursLeft <= 24) score += 30;
        else if (hoursLeft <= 72) score += 15;
      }
      // تطابق با بهترین ساعت
      int suggestedHour = 9;
      if (habitProfile.bestHours.isNotEmpty) {
        suggestedHour = habitProfile.bestHours.first;
        // اگر انرژی کار = high و ساعت اوج صبح است، امتیاز بیشتر
        if (task.energy == EnergyLevel.high && suggestedHour <= 12) score += 10;
        if (task.energy == EnergyLevel.low && suggestedHour >= 18) score += 10;
      }
      // دسته چالشی → صبح زود
      if (habitProfile.procrastinationCategories.contains(task.category)) {
        suggestedHour = 9;
        score += 5;
      }

      final suggestedStart = DateTime(current.year, current.month, current.day, suggestedHour).isBefore(current)
          ? DateTime(current.year, current.month, current.day, suggestedHour).add(const Duration(days: 1))
          : DateTime(current.year, current.month, current.day, suggestedHour);

      String reason;
      if (task.isOverdue) reason = 'عقب‌افتاده — فوری';
      else if (habitProfile.bestHours.isNotEmpty) reason = 'بهترین بازده‌ات ساعت ${PersianFormat.digits(suggestedHour)}:۰۰';
      else reason = 'اولویت بالا';

      scored.add(ScheduledTaskSuggestion(task: task, suggestedStart: suggestedStart, reason: reason, priority: score));
    }

    scored.sort((a, b) => b.priority.compareTo(a.priority));
    return scored.take(5).toList();
  }

  /// هشدار هوشمند ۷ روز آینده
  List<String> next7DaysWarnings({
    required List<FinanceTransaction> transactions,
    required List<Task> tasks,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final warnings = <String>[];

    // پیش‌بینی هزینه ۷ روز
    final expenseForecast = forecast30Days(transactions: transactions, type: FinanceTransactionType.expense, now: current).take(7).toList();
    final total7 = expenseForecast.fold<int>(0, (s, p) => s + p.predictedValue);
    if (total7 > 5000000) {
      warnings.add('⚠️ هفته آینده حدود ${PersianFormat.money(total7)} هزینه پیش‌بینی می‌شود — بودجه را چک کن');
    }

    // کارهای با مهلت ۷ روز
    final dueSoon = tasks.where((t) => !t.isDone && t.dueAt != null && t.dueAt!.isAfter(current) && t.dueAt!.difference(current).inDays <= 7).length;
    if (dueSoon >= 5) warnings.add('📅 ${PersianFormat.digits(dueSoon)} کار تا ۷ روز آینده مهلت دارد — برنامه‌ریزی کن');

    if (warnings.isEmpty) warnings.add('✅ هفته آینده آرام به نظر می‌رسد');
    return warnings;
  }

  List<int> _dailyTotals(List<FinanceTransaction> txs, FinanceTransactionType type, {required int days, required DateTime now}) {
    final result = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final sum = txs.where((t) => t.type == type && !t.createdAt.isBefore(day) && t.createdAt.isBefore(next)).fold<int>(0, (s, t) => s + t.amount);
      result.add(sum);
    }
    return result;
  }
}
