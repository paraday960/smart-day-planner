import 'dart:math';

import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';

/// پروفایل پیشرفته یادگیری عادت‌ها — نسل جدید WorkLearningService
/// با پیش‌بینی، تحلیل روند و پیشنهاد خودکار
class AdvancedHabitProfile {
  const AdvancedHabitProfile({
    required this.completionRate,
    required this.streakDays,
    required this.avgTasksPerDay,
    required this.bestHours,
    required this.bestWeekday,
    required this.worstWeekday,
    required this.productivityTrend,
    required this.predictedMonthlyExpense,
    required this.predictedMonthlyIncome,
    required this.categoryHabits,
    required this.procrastinationCategories,
    required this.weeklyTrend,
    required this.totalCompleted,
    required this.totalOpen,
  });

  /// نرخ تکمیل کارها ۰ تا ۱
  final double completionRate;

  /// streak فعلی (روزهای متوالی با حداقل ۱ کار تکمیل)
  final int streakDays;

  /// میانگین کار تکمیل در روز (۳۰ روز اخیر)
  final double avgTasksPerDay;

  /// بهترین ساعت‌های روز برای کار (۰-۲۳)
  final List<int> bestHours;

  /// بهترین روز هفته
  final int? bestWeekday;

  /// ضعیف‌ترین روز هفته
  final int? worstWeekday;

  /// روند بهره‌وری: + یعنی بهتر از هفته قبل، - یعنی افت
  final double productivityTrend;

  /// پیش‌بینی هزینه ماه آینده
  final int predictedMonthlyExpense;

  /// پیش‌بینی درآمد ماه آینده
  final int predictedMonthlyIncome;

  /// تحلیل هر دسته
  final List<CategoryHabit> categoryHabits;

  /// دسته‌هایی که زیاد عقب می‌افتند
  final List<String> procrastinationCategories;

  /// روند هفتگی تعداد کارهای تکمیل
  final List<int> weeklyTrend;

  final int totalCompleted;
  final int totalOpen;

  bool get hasEnoughData => totalCompleted >= 3;
}

class CategoryHabit {
  const CategoryHabit({
    required this.category,
    required this.completedCount,
    required this.avgEstimated,
    required this.avgActual,
    required this.accuracyRatio,
    required this.bestHour,
  });

  final String category;
  final int completedCount;
  final double avgEstimated;
  final double avgActual;
  /// نسبت واقعی به تخمینی (۱.۲ یعنی ۲۰٪ بیشتر زمان برده)
  final double accuracyRatio;
  final int? bestHour;

  String get insight {
    if (accuracyRatio >= 1.3) {
      return 'در «$category» معمولا ${PersianFormat.digits(((accuracyRatio - 1) * 100).round())}٪ بیشتر از تخمینت زمان می‌بری — دفعه بعد بیشتر در نظر بگیر';
    } else if (accuracyRatio <= 0.7) {
      return 'در «$category» خیلی سریع‌تری از تخمینت — می‌تونی فشرده‌تر برنامه بچینی';
    } else if (accuracyRatio >= 1.15) {
      return 'در «$category» کمی خوش‌بینانه تخمین می‌زنی';
    }
    return 'تخمین زمان «$category» دقیق است';
  }
}

class AdvancedHabitLearningService {
  const AdvancedHabitLearningService();

  static const int _windowDays = 30;

  AdvancedHabitProfile analyze({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final windowStart = current.subtract(const Duration(days: _windowDays));

    // ── نرخ تکمیل و streak ──
    final totalCompleted = tasks.where((t) => t.isDone).length;
    final totalOpen = tasks.where((t) => !t.isDone).length;
    final total = totalCompleted + totalOpen;
    final completionRate = total == 0 ? 0.0 : totalCompleted / total;

    final streak = _calculateStreak(tasks, current);
    final avgTasksPerDay = _avgTasksPerDay(tasks, windowStart);

    // ── بهترین ساعت‌ها ──
    final bestHours = _bestHours(tasks);
    final weekdayStats = _weekdayStats(tasks, transactions);
    
    // ── روند بهره‌وری ──
    final trend = _productivityTrend(tasks, current);
    final weeklyTrend = _weeklyTrend(tasks, current);

    // ── پیش‌بینی مالی ──
    final predictedExpense = _predictNextMonth(transactions, FinanceTransactionType.expense, current);
    final predictedIncome = _predictNextMonth(transactions, FinanceTransactionType.income, current);

    // ── تحلیل دسته‌ها ──
    final categoryHabits = _categoryHabits(tasks);
    final procrastination = _procrastinationCategories(tasks);

    return AdvancedHabitProfile(
      completionRate: completionRate,
      streakDays: streak,
      avgTasksPerDay: avgTasksPerDay,
      bestHours: bestHours,
      bestWeekday: weekdayStats.best,
      worstWeekday: weekdayStats.worst,
      productivityTrend: trend,
      predictedMonthlyExpense: predictedExpense,
      predictedMonthlyIncome: predictedIncome,
      categoryHabits: categoryHabits,
      procrastinationCategories: procrastination,
      weeklyTrend: weeklyTrend,
      totalCompleted: totalCompleted,
      totalOpen: totalOpen,
    );
  }

  /// پیشنهادهای خودکار هوشمند - ۳ تا ۶ جمله فارسی
  List<String> suggestions(AdvancedHabitProfile profile, {DateTime? now}) {
    final result = <String>[];
    final current = now ?? DateTime.now();

    // streak
    if (profile.streakDays >= 7) {
      result.add('🔥 ${PersianFormat.digits(profile.streakDays)} روز متوالی فعال بودی — همین روند رو نگه دار!');
    } else if (profile.streakDays >= 3) {
      result.add('روند خوبی داری (${PersianFormat.digits(profile.streakDays)} روز متوالی) — فردا هم حداقل یک کار ببند تا streak نشکنه');
    } else if (profile.streakDays == 0 && profile.hasEnoughData) {
      result.add('امروز هنوز کاری نبستی — یه کار ۱۵ دقیقه‌ای انجام بده تا streak دوباره شروع شه');
    }

    // نرخ تکمیل
    if (profile.completionRate >= 0.8) {
      result.add('نرخ تکمیلت عالیه (${PersianFormat.digits((profile.completionRate * 100).round())}٪) — می‌تونی کارهای چالشی‌تر اضافه کنی');
    } else if (profile.completionRate < 0.4 && profile.totalCompleted + profile.totalOpen >= 5) {
      result.add('نرخ تکمیل ${PersianFormat.digits((profile.completionRate * 100).round())}٪ — کارها رو کوچک‌تر کن، هر کار بزرگ رو به ۲-۳ تکه ۳۰ دقیقه‌ای بشکن');
    }

    // بهترین ساعت
    if (profile.bestHours.isNotEmpty) {
      final hours = profile.bestHours.take(2).map((h) => '${PersianFormat.digits(h)}:۰۰').join(' و ');
      result.add('بیشترین بازده‌ات ساعت $hours بوده — کارهای مهم رو اون بازه بچین');
    }

    // روز هفته
    if (profile.bestWeekday != null && profile.worstWeekday != null) {
      result.add('پربازده‌ترین روزت ${_weekdayName(profile.bestWeekday!)} و کم‌بازده‌ترین ${_weekdayName(profile.worstWeekday!)} — کارهای سنگین رو ${_weekdayName(profile.bestWeekday!)} بذار');
    }

    // روند
    if (profile.productivityTrend > 0.2) {
      result.add('نسبت به هفته قبل ${PersianFormat.digits((profile.productivityTrend * 100).round())}٪ رشد داشتی — عالیه!');
    } else if (profile.productivityTrend < -0.2) {
      result.add('این هفته نسبت به قبل افت داشتی — دلیلش رو چک کن: خستگی؟ کارهای بزرگ؟');
    }

    // پیش‌بینی مالی
    if (profile.predictedMonthlyExpense > 0) {
      result.add('پیش‌بینی هزینه ماه بعد: حدود ${PersianFormat.money(profile.predictedMonthlyExpense)}');
    }
    if (profile.predictedMonthlyIncome > 0 && profile.predictedMonthlyExpense > 0) {
      final net = profile.predictedMonthlyIncome - profile.predictedMonthlyExpense;
      if (net < 0) {
        result.add('⚠️ با روند فعلی ماه بعد ${PersianFormat.money(net.abs())} کسری داری — هزینه‌ها رو کم کن یا درآمد رو ببر بالا');
      } else if (net > 0) {
        result.add('پیش‌بینی تراز ماه بعد: ${PersianFormat.money(net)} مثبت — می‌تونی پس‌انداز کنی');
      }
    }

    // اهمال‌کاری
    for (final cat in profile.procrastinationCategories.take(1)) {
      result.add('دسته «$cat» زیاد عقب می‌افته — اون رو به کارهای ۱۵ دقیقه‌ای خرد کن');
    }

    // تخمین دسته‌ها
    for (final ch in profile.categoryHabits.where((c) => c.accuracyRatio >= 1.3 || c.accuracyRatio <= 0.7).take(1)) {
      result.add(ch.insight);
    }

    if (result.isEmpty) {
      result.add('برای پیشنهاد دقیق‌تر، چند روز کار و تراکنش ثبت کن تا الگوهات رو یاد بگیرم');
    }

    // ساعت فعلی
    final hour = current.hour;
    if (hour >= 22) {
      result.add('الان دیروقته — فقط مرور فردا رو انجام بده، کار سنگین نذار');
    }

    return result.take(6).toList();
  }

  /// خلاصه یک خطی برای داشبورد
  String dashboardSummary(AdvancedHabitProfile p) {
    if (!p.hasEnoughData) return 'هنوز داده کافی برای تحلیل عادت ندارم — چند کار تکمیل کن';
    final parts = <String>[];
    parts.add('تکمیل ${PersianFormat.digits((p.completionRate * 100).round())}٪');
    if (p.streakDays > 0) parts.add('streak ${PersianFormat.digits(p.streakDays)} روز');
    parts.add('${PersianFormat.digits(p.avgTasksPerDay.toStringAsFixed(1))} کار/روز');
    if (p.productivityTrend > 0.1) parts.add('روند صعودی 📈');
    if (p.productivityTrend < -0.1) parts.add('روند نزولی 📉');
    return parts.join(' • ');
  }

  // ── helpers ──

  int _calculateStreak(List<Task> tasks, DateTime now) {
    final completedDays = tasks
        .where((t) => t.isDone && t.completedAt != null)
        .map((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day))
        .toSet();
    if (completedDays.isEmpty) return 0;
    var streak = 0;
    var day = DateTime(now.year, now.month, now.day);
    // اگر امروز کاری نبسته، از دیروز شروع کن ولی streak امروز صفر حساب میشه اگر امروز ناقصه
    // منطق: streak روزهای متوالی تا امروز/دیروز
    if (!completedDays.contains(day)) {
      day = day.subtract(const Duration(days: 1));
      if (!completedDays.contains(day)) return 0;
    }
    while (completedDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _avgTasksPerDay(List<Task> tasks, DateTime start) {
    final done = tasks.where((t) => t.isDone && t.completedAt != null && !t.completedAt!.isBefore(start)).toList();
    if (done.isEmpty) return 0;
    // میانگین روی روزهایی که حداقل یک کار تکمیل شده (روزهای فعال).
    // قبلاً به‌اشتباه بر روزهای تقویمیِ کل بازه تقسیم می‌شد و متغیر
    // `activeDays` محاسبه می‌شد ولی استفاده نمی‌شد (کد مرده + ناسازگاری با توضیح).
    final activeDays = done.map((t) => DateTime(t.completedAt!.year, t.completedAt!.month, t.completedAt!.day)).toSet().length;
    if (activeDays == 0) return 0;
    return done.length / activeDays;
  }

  List<int> _bestHours(List<Task> tasks) {
    final done = tasks.where((t) => t.isDone && t.completedAt != null).toList();
    if (done.length < 3) return [];
    final byHour = <int, int>{};
    for (final t in done) {
      byHour.update(t.completedAt!.hour, (v) => v + 1, ifAbsent: () => 1);
    }
    final sorted = byHour.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  ({int? best, int? worst}) _weekdayStats(List<Task> tasks, List<FinanceTransaction> txs) {
    final byDay = <int, int>{};
    for (final t in tasks.where((t) => t.isDone && t.completedAt != null)) {
      byDay.update(t.completedAt!.weekday, (v) => v + 1, ifAbsent: () => 1);
    }
    // درآمد هم اضافه کن با وزن
    for (final tx in txs.where((t) => t.type == FinanceTransactionType.income)) {
      byDay.update(tx.createdAt.weekday, (v) => v + 1, ifAbsent: () => 1);
    }
    if (byDay.length < 2) return (best: null, worst: null);
    final best = byDay.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final worst = byDay.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    if (best == worst) return (best: best, worst: null);
    return (best: best, worst: worst);
  }

  double _productivityTrend(List<Task> tasks, DateTime now) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final thisWeek = tasks.where((t) => t.isDone && t.completedAt != null && t.completedAt!.isAfter(weekAgo)).length;
    final lastWeek = tasks.where((t) => t.isDone && t.completedAt != null && t.completedAt!.isAfter(twoWeeksAgo) && t.completedAt!.isBefore(weekAgo)).length;
    if (lastWeek == 0) return thisWeek > 0 ? 1.0 : 0.0;
    return (thisWeek - lastWeek) / lastWeek;
  }

  List<int> _weeklyTrend(List<Task> tasks, DateTime now) {
    final result = <int>[];
    for (var i = 3; i >= 0; i--) {
      final start = now.subtract(Duration(days: (i + 1) * 7));
      final end = now.subtract(Duration(days: i * 7));
      final count = tasks.where((t) => t.isDone && t.completedAt != null && t.completedAt!.isAfter(start) && !t.completedAt!.isAfter(end)).length;
      result.add(count);
    }
    return result;
  }

  int _predictNextMonth(List<FinanceTransaction> txs, FinanceTransactionType type, DateTime now) {
    if (txs.isEmpty) return 0;
    // میانگین موزون ۳ ماه اخیر: ماه اخیر وزن 0.5، قبلی 0.3، قبل‌تر 0.2
    final m0Start = DateTime(now.year, now.month, 1);
    final m1Start = DateTime(now.year, now.month - 1, 1);
    final m2Start = DateTime(now.year, now.month - 2, 1);
    // handle year wrap
    int sum0 = _sumInRange(txs, type, m0Start, now);
    int sum1 = _sumInRange(txs, type, m1Start, m0Start);
    int sum2 = _sumInRange(txs, type, m2Start, m1Start);
    
    // اگر فقط ماه جاری داده داریم، بر اساس روز
    if (sum1 == 0 && sum2 == 0) {
      final daysPassed = now.day.clamp(1, 30);
      if (daysPassed < 3) return sum0;
      return (sum0 / daysPassed * 30).round();
    }
    double weighted = sum0 * 0.5 + sum1 * 0.3 + sum2 * 0.2;
    // اگر ماه جاری ناقصه، نرمال کن
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final progress = now.day / daysInMonth;
    if (progress < 0.9 && sum0 > 0) {
      // تخمین کل ماه جاری از روی پیشرفت
      final estimated0 = (sum0 / progress).round();
      weighted = estimated0 * 0.5 + sum1 * 0.3 + sum2 * 0.2;
    }
    return weighted.round();
  }

  int _sumInRange(List<FinanceTransaction> txs, FinanceTransactionType type, DateTime from, DateTime to) {
    var sum = 0;
    for (final t in txs) {
      if (t.type != type) continue;
      if (t.createdAt.isBefore(from) || !t.createdAt.isBefore(to)) continue;
      sum += t.amount;
    }
    return sum;
  }

  List<CategoryHabit> _categoryHabits(List<Task> tasks) {
    final done = tasks.where((t) => t.isDone && t.actualMinutes != null && t.actualMinutes! > 0).toList();
    if (done.isEmpty) return [];
    final byCat = <String, List<Task>>{};
    for (final t in done) {
      byCat.putIfAbsent(t.category, () => []).add(t);
    }
    final result = <CategoryHabit>[];
    for (final e in byCat.entries) {
      if (e.value.length < 2) continue;
      final est = e.value.fold<int>(0, (s, t) => s + t.estimatedMinutes) / e.value.length;
      final act = e.value.fold<int>(0, (s, t) => s + t.actualMinutes!) / e.value.length;
      final ratio = act / max(1, est);
      // بهترین ساعت این دسته
      final byHour = <int, int>{};
      for (final t in e.value) {
        if (t.completedAt != null) byHour.update(t.completedAt!.hour, (v) => v + 1, ifAbsent: () => 1);
      }
      int? bestHour;
      if (byHour.isNotEmpty) bestHour = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      result.add(CategoryHabit(category: e.key, completedCount: e.value.length, avgEstimated: est, avgActual: act, accuracyRatio: ratio, bestHour: bestHour));
    }
    result.sort((a, b) => b.accuracyRatio.compareTo(a.accuracyRatio));
    return result;
  }

  List<String> _procrastinationCategories(List<Task> tasks) {
    final overdue = tasks.where((t) => t.isOverdue).toList();
    if (overdue.isEmpty) return [];
    final byCat = <String, int>{};
    for (final t in overdue) {
      byCat.update(t.category, (v) => v + 1, ifAbsent: () => 1);
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(2).map((e) => e.key).toList();
  }

  String _weekdayName(int w) {
    switch (w) {
      case DateTime.saturday: return 'شنبه';
      case DateTime.sunday: return 'یکشنبه';
      case DateTime.monday: return 'دوشنبه';
      case DateTime.tuesday: return 'سه‌شنبه';
      case DateTime.wednesday: return 'چهارشنبه';
      case DateTime.thursday: return 'پنجشنبه';
      case DateTime.friday: return 'جمعه';
      default: return '';
    }
  }
}
