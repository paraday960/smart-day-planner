import '../models/finance_transaction.dart';
import '../models/task.dart';

/// پروفایل کاریِ یادگرفته‌شده از سابقهٔ کاربر.
///
/// از کارهای انجام‌شده (زمان واقعی) و تراکنش‌های درآمدی (زمان کارکرد)
/// محاسبه می‌شود تا دستیار بتواند بفهمد «کاربر چقدر کار می‌کند و
/// روزی چقدر درآمد دارد».
class WorkProfile {
  const WorkProfile({
    required this.avgDailyWorkMinutes,
    required this.avgHourlyRate,
    required this.dailyEarningCapacity,
    required this.historyDays,
    required this.sampleCount,
  });

  static const WorkProfile empty = WorkProfile(
    avgDailyWorkMinutes: 0,
    avgHourlyRate: 0,
    dailyEarningCapacity: 0,
    historyDays: 0,
    sampleCount: 0,
  );

  /// میانگین دقیقهٔ کار در روز (از سابقهٔ ۳۰ روز اخیر).
  final double avgDailyWorkMinutes;

  /// میانگین درآمد ساعتی (تومان بر ساعت).
  final double avgHourlyRate;

  /// توان درآمدی روزانه = (دقیقهٔ کار روزانه / ۶۰) × درآمد ساعتی.
  final double dailyEarningCapacity;

  /// تعداد روزهایی که دادهٔ کاری در آن‌ها ثبت شده.
  final int historyDays;

  /// تعداد نمونه‌ها (کارهای تکمیل‌شده + تراکنش‌های درآمدی با زمان).
  final int sampleCount;

  /// آیا دادهٔ کافی برای پیش‌بینی داریم؟
  bool get hasEnoughData => sampleCount >= 3 && (avgDailyWorkMinutes > 0 || avgHourlyRate > 0);
}

/// سرویس یادگیری عادت کاری کاربر — کاملاً pure و تست‌پذیر.
class WorkLearningService {
  const WorkLearningService();

  static const int _windowDays = 30;

  /// ساخت پروفایل کاری از سابقه.
  WorkProfile profile({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final windowStart = current.subtract(const Duration(days: _windowDays));

    // ── دقیقهٔ کار در ۳۰ روز اخیر ──
    var totalMinutes = 0;
    final workDays = <DateTime>{};

    // کارهای تکمیل‌شده با زمان واقعی
    for (final task in tasks) {
      final completed = task.completedAt;
      final actual = task.actualMinutes;
      if (completed == null || actual == null || actual <= 0) continue;
      if (completed.isBefore(windowStart)) continue;
      totalMinutes += actual;
      workDays.add(DateTime(completed.year, completed.month, completed.day));
    }

    // تراکنش‌های درآمدی روزهای کاری را مشخص می‌کنند (برای تعداد روزها)،
    // ولی دقیقه‌هایشان دوباره به totalMinutes اضافه نمی‌شود تا کار دو بار شمرده نشود.

    // تراکنش‌های درآمدی با زمان کارکرد: فقط برای شمارش روزهای کاری
    for (final tx in transactions) {
      if (tx.type != FinanceTransactionType.income) continue;
      final minutes = tx.minutesWorked;
      if (minutes == null || minutes <= 0) continue;
      if (tx.createdAt.isBefore(windowStart)) continue;
      workDays.add(DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day));
    }

    // ── میانگین درآمد ساعتی (کل سابقه برای پایداری) ──
    double hourlyRate = 0;
    var rateSamples = 0;
    for (final tx in transactions) {
      if (tx.type != FinanceTransactionType.income) continue;
      final minutes = tx.minutesWorked;
      if (minutes == null || minutes <= 0) continue;
      hourlyRate += tx.amount / minutes * 60;
      rateSamples++;
    }
    if (rateSamples > 0) hourlyRate /= rateSamples;

    final dayCount = workDays.isEmpty ? 0 : workDays.length;
    final avgDailyMinutes = dayCount == 0 ? 0.0 : totalMinutes / dayCount;
    final dailyCapacity = (avgDailyMinutes / 60) * hourlyRate;

    return WorkProfile(
      avgDailyWorkMinutes: avgDailyMinutes,
      avgHourlyRate: hourlyRate,
      dailyEarningCapacity: dailyCapacity,
      historyDays: dayCount,
      sampleCount: rateSamples + workDays.length,
    );
  }
}
