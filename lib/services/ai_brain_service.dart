import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'advanced_habit_learning_service.dart';
import 'debt_repayment_planner.dart';
import 'finance_insights_service.dart';
import 'finance_repository.dart';
import 'smart_insights_service.dart';
import 'brain_memory_service.dart';
import 'feedback_learning_service.dart';
import 'work_learning_service.dart';

/// 🧠 مغز هوشمند یکپارچه — همه هوش‌ها در یک جا
/// 
/// قبلا ۶ سرویس جدا داشتیم که هر کدام یک گوشه را تحلیل می‌کرد.
/// حالا AIBrain همه را ترکیب می‌کند + حافظه بلندمدت شخصی‌سازی شده.
class AIBrainProfile {
  const AIBrainProfile({
    required this.workProfile,
    required this.habitProfile,
    required this.financeHealth,
    required this.debtPlan,
    required this.personalizedInsights,
    required this.brainScore,
    required this.mood,
    required this.nextAction,
    this.memory,
  });

  final WorkProfile workProfile;
  final AdvancedHabitProfile habitProfile;
  final FinanceHealth financeHealth;
  final RepaymentPlan? debtPlan;
  /// توصیه‌های شخصی‌سازی شده برای این کاربر خاص
  final List<String> personalizedInsights;
  /// امتیاز کلی مغز ۰-۱۰۰ (سلامت برنامه‌ریزی + مالی + عادت)
  final int brainScore;
  /// حال کلی: excellent / good / warning / critical
  final String mood;
  /// بهترین اقدام بعدی پیشنهادی مغز
  final String nextAction;
  /// حافظه بلندمدت
  final BrainLongTermMemory? memory;
}

class FinanceHealth {
  const FinanceHealth({
    required this.monthIncome,
    required this.monthExpense,
    required this.net,
    required this.healthLabel,
    required this.anomaly,
  });
  final int monthIncome;
  final int monthExpense;
  final int net;
  final String healthLabel; // سالم / هشدار / بحرانی
  final ExpenseAnomaly? anomaly;
}

/// حافظه بلندمدت کاربر — یادگیری ترجیحات شخصی
class UserMemory {
  const UserMemory({
    this.favoriteCategories = const [],
    this.mostProductiveHour,
    this.avgCompletionRate = 0,
    this.totalInteractions = 0,
  });

  final List<String> favoriteCategories;
  final int? mostProductiveHour;
  final double avgCompletionRate;
  final int totalInteractions;

  UserMemory copyWith({
    List<String>? favoriteCategories,
    int? mostProductiveHour,
    double? avgCompletionRate,
    int? totalInteractions,
  }) {
    return UserMemory(
      favoriteCategories: favoriteCategories ?? this.favoriteCategories,
      mostProductiveHour: mostProductiveHour ?? this.mostProductiveHour,
      avgCompletionRate: avgCompletionRate ?? this.avgCompletionRate,
      totalInteractions: totalInteractions ?? this.totalInteractions,
    );
  }
}

/// 🧠 سرویس مغز یکپارچه
class AIBrainService {
  const AIBrainService({
    this.workLearning = const WorkLearningService(),
    this.habitLearning = const AdvancedHabitLearningService(),
    this.financeInsights = const FinanceInsightsService(),
    this.smartInsights = const SmartInsightsService(),
    this.debtPlanner = const DebtRepaymentPlanner(),
  });

  final WorkLearningService workLearning;
  final AdvancedHabitLearningService habitLearning;
  final FinanceInsightsService financeInsights;
  final SmartInsightsService smartInsights;
  final DebtRepaymentPlanner debtPlanner;

  // کش ۵ دقیقه‌ای برای کارآمدی — UI گیر نمی‌کنه
  static AIBrainProfile? _cachedProfile;
  static DateTime? _cachedAt;
  static int? _cachedHash;
  static const _cacheTtl = Duration(minutes: 5);

  static int _hashInputs(List<Task> tasks, List<FinanceTransaction> txs, List<DebtItem> debts) {
    var h = tasks.length * 1000003 ^ txs.length * 9176 ^ debts.length * 31;
    if (tasks.isNotEmpty) h ^= tasks.first.id.hashCode ^ tasks.last.id.hashCode;
    if (txs.isNotEmpty) h ^= txs.first.id.hashCode;
    return h;
  }

  static bool _isCacheValid(int hash) {
    if (_cachedProfile == null || _cachedAt == null || _cachedHash == null) return false;
    if (_cachedHash != hash) return false;
    if (DateTime.now().difference(_cachedAt!) > _cacheTtl) return false;
    return true;
  }

  /// پاک کردن کش (بعد از تغییر داده)
  static void invalidateCache() {
    _cachedProfile = null;
    _cachedAt = null;
    _cachedHash = null;
  }

  /// تحلیل جامع — ورودی همه داده‌های کاربر، خروجی یک پروفایل واحد (با کش ۵ دقیقه‌ای)
  AIBrainProfile analyze({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    required FinanceRepository finance,
    List<DebtItem> debts = const [],
    DateTime? now,
    bool useCache = true,
  }) {
    final hash = _hashInputs(tasks, transactions, debts);
    if (useCache && _isCacheValid(hash)) {
      return _cachedProfile!;
    }
    final current = now ?? DateTime.now();

    // ۱. پروفایل‌های پایه
    final workProfile = workLearning.profile(tasks: tasks, transactions: transactions, now: current);
    final habitProfile = habitLearning.analyze(tasks: tasks, transactions: transactions, now: current);

    // ۲. سلامت مالی
    final health = _financeHealth(transactions, finance, current);

    // ۳. برنامه بدهی (اگر بدهی دارد)
    RepaymentPlan? debtPlan;
    if (debts.isNotEmpty) {
      final repaymentDebts = debts.map((d) => RepaymentDebt(
        personName: d.personName,
        amount: d.remainingAmount,
        dueAt: d.dueAt,
      )).toList();
      debtPlan = debtPlanner.plan(debts: repaymentDebts, profile: workProfile);
    }

    // ۴. امتیاز مغز و حال
    final score = _brainScore(habitProfile, health, debtPlan);
    final mood = _mood(score, health, habitProfile);

    // ۵. توصیه‌های شخصی‌سازی شده (ترکیب همه)
    final insights = _personalizedInsights(
      tasks: tasks,
      habitProfile: habitProfile,
      health: health,
      debtPlan: debtPlan,
      workProfile: workProfile,
      finance: finance,
    );

    // ۶. بهترین اقدام بعدی
    final nextAction = _nextAction(tasks: tasks, habitProfile: habitProfile, health: health, debtPlan: debtPlan);

    final profile = AIBrainProfile(
      workProfile: workProfile,
      habitProfile: habitProfile,
      financeHealth: health,
      debtPlan: debtPlan,
      personalizedInsights: insights,
      brainScore: score,
      mood: mood,
      nextAction: nextAction,
    );
    _cachedProfile = profile;
    _cachedAt = DateTime.now();
    _cachedHash = hash;
    return profile;
  }

  /// پیام صبح بخیر شخصی‌سازی شده
  String morningBriefing(AIBrainProfile brain, List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).length;
    final buf = StringBuffer();
    
    // سلام شخصی بر اساس حال
    if (brain.mood == 'excellent') {
      buf.writeln('صبح بخیر قهرمان! 🌟 امتیاز مغزت ${PersianFormat.digits(brain.brainScore)} از ۱۰۰ — عالی پیش میری!');
    } else if (brain.mood == 'good') {
      buf.writeln('صبح بخیر! ☀️ امتیازت ${PersianFormat.digits(brain.brainScore)} — امروز می‌تونی بهتر هم بشی');
    } else if (brain.mood == 'warning') {
      buf.writeln('صبح بخیر — امروز کمی حواست جمع‌تر باش ⚠️ امتیاز ${PersianFormat.digits(brain.brainScore)}');
    } else {
      buf.writeln('صبح بخیر — امروز روز جبرانه 💪 امتیاز ${PersianFormat.digits(brain.brainScore)}، ولی می‌تونی برگردی');
    }

    buf.writeln('📋 ${PersianFormat.digits(open)} کار باز داری');
    buf.writeln('🎯 اقدام پیشنهادی: ${brain.nextAction}');
    
    if (brain.habitProfile.streakDays >= 3) {
      buf.writeln('🔥 استریک ${PersianFormat.digits(brain.habitProfile.streakDays)} روزه‌ات رو نشکن!');
    }

    if (brain.debtPlan != null && brain.debtPlan!.totalRemaining > 0) {
      buf.writeln('💳 بدهی: ${PersianFormat.money(brain.debtPlan!.totalRemaining)} — ${brain.debtPlan!.feasible ? 'شدنیه' : 'نیاز به تلاش بیشتر'}');
    }

    return buf.toString();
  }

  /// تحلیل + یادگیری خودکار حافظه بلندمدت (باید await شود)
  Future<AIBrainProfile> analyzeWithMemory({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    required FinanceRepository finance,
    List<DebtItem> debts = const [],
    DateTime? now,
  }) async {
    final profile = analyze(tasks: tasks, transactions: transactions, finance: finance, debts: debts, now: now);
    // یادگیری خودکار حافظه
    try {
      final memSvc = BrainMemoryService();
      final mem = await memSvc.learn(tasks: tasks, transactions: transactions);
      // اعمال وزن بازخورد
      final fbSvc = FeedbackLearningService();
      final weights = await fbSvc.getWeights();
      final adjustedInsights = _applyFeedbackWeights(profile.personalizedInsights, weights);
      return AIBrainProfile(
        workProfile: profile.workProfile,
        habitProfile: profile.habitProfile,
        financeHealth: profile.financeHealth,
        debtPlan: profile.debtPlan,
        personalizedInsights: adjustedInsights,
        brainScore: profile.brainScore,
        mood: profile.mood,
        nextAction: profile.nextAction,
        memory: mem,
      );
    } catch (_) {
      return profile;
    }
  }

  List<String> _applyFeedbackWeights(List<String> insights, Map<String, double> weights) {
    if (weights.isEmpty) return insights;
    // وزن واقعی: هر دسته وزن جدا دارد، پیشنهادهای کم‌وزن آخر می‌روند
    final scored = <MapEntry<String, double>>[];
    for (final ins in insights) {
      double w = 1.0;
      if (ins.contains('ساعت') || ins.contains('استریک') || ins.contains('عادت')) w = weights['habit'] ?? weights['general'] ?? 1.0;
      else if (ins.contains('💸') || ins.contains('💰') || ins.contains('تراز')) w = weights['finance'] ?? weights['general'] ?? 1.0;
      else if (ins.contains('بدهی')) w = weights['debt'] ?? weights['general'] ?? 1.0;
      else w = weights['general'] ?? 1.0;
      scored.add(MapEntry(ins, w));
    }
    // اگر هیچ پیشنهادی وجود نداشت، بدون اعمال وزن برگرد (جلوگیری از StateError روی scored.first)
    if (scored.isEmpty) return insights;
    // مرتب‌سازی نزولی بر اساس وزن (وزن بالا اول)
    scored.sort((a, b) => b.value.compareTo(a.value));
    // اگر وزن <0.6، آن دسته را حذف کن (کاربر نخواسته)
    final filtered = scored.where((e) => e.value >= 0.6).map((e) => e.key).toList();
    // اگر همه حذف شدند، حداقل یکی را نگه دار
    return filtered.isEmpty ? [scored.first.key] : filtered;
  }

  /// خلاصه یک خطی برای داشبورد
  String dashboardOneLiner(AIBrainProfile brain) {
    return 'مغز: ${PersianFormat.digits(brain.brainScore)}/۱۰۰ • ${brain.mood == 'excellent' ? 'عالی' : brain.mood == 'good' ? 'خوب' : brain.mood == 'warning' ? 'هشدار' : 'بحرانی'} • ${brain.nextAction}';
  }

  // ── private ──

  FinanceHealth _financeHealth(List<FinanceTransaction> txs, FinanceRepository finance, DateTime now) {
    final monthStart = finance.currentJalaliMonthStart();
    final monthEnd = finance.currentJalaliMonthEnd();
    final income = finance.total(type: FinanceTransactionType.income, from: monthStart, to: monthEnd);
    final expense = finance.total(type: FinanceTransactionType.expense, from: monthStart, to: monthEnd);
    final net = income - expense;

    String label;
    if (income == 0 && expense == 0) label = 'بدون داده';
    else if (income == 0 && expense > 0) label = 'بحرانی';
    else if (net < 0) label = 'کسری';
    else if (expense / (income == 0 ? 1 : income) > 0.8) label = 'هشدار';
    else label = 'سالم';

    final anomalies = financeInsights.expenseAnomalies(txs);
    return FinanceHealth(
      monthIncome: income,
      monthExpense: expense,
      net: net,
      healthLabel: label,
      anomaly: anomalies.isEmpty ? null : anomalies.first,
    );
  }

  int _brainScore(AdvancedHabitProfile habit, FinanceHealth health, RepaymentPlan? debtPlan) {
    var score = 50;
    // عادت ۰-۳۰
    score += (habit.completionRate * 20).round(); // تا ۲۰
    if (habit.streakDays >= 7) score += 10;
    else if (habit.streakDays >= 3) score += 5;
    if (habit.productivityTrend > 0.1) score += 5;
    if (habit.productivityTrend < -0.2) score -= 5;

    // مالی ۰-۲۰
    if (health.healthLabel == 'سالم') score += 15;
    else if (health.healthLabel == 'هشدار') score += 5;
    else if (health.healthLabel == 'کسری' || health.healthLabel == 'بحرانی') score -= 10;
    if (health.anomaly != null) score -= 5;

    // بدهی ۰-۱۵
    if (debtPlan != null) {
      if (debtPlan.feasible) score += 10;
      else score -= 10;
      if (debtPlan.totalRemaining == 0) score += 5;
    } else {
      score += 5; // بدون بدهی امتیاز
    }

    return score.clamp(0, 100);
  }

  String _mood(int score, FinanceHealth health, AdvancedHabitProfile habit) {
    if (score >= 80) return 'excellent';
    if (score >= 60) return 'good';
    if (score >= 40) return 'warning';
    return 'critical';
  }

  List<String> _personalizedInsights({
    required List<Task> tasks,
    required AdvancedHabitProfile habitProfile,
    required FinanceHealth health,
    required RepaymentPlan? debtPlan,
    required WorkProfile workProfile,
    required FinanceRepository finance,
  }) {
    final result = <String>[];

    // از habitLearning — با توضیح چرایی
    for (final s in habitLearning.suggestions(habitProfile).take(2)) {
      // توضیح‌پذیری: دلیل را از روی داده اضافه کن
      String explain = '';
      if (s.contains('ساعت') && habitProfile.bestHours.isNotEmpty) {
        final hour = habitProfile.bestHours.first;
        final count = tasks.where((t) => t.isDone && t.completedAt?.hour == hour).length;
        explain = ' (چون ${PersianFormat.digits(count)} کار رو همین ساعت تموم کردی)';
      } else if (s.contains('استریک')) {
        explain = ' (تداوم = بهره‌وری بیشتر)';
      }
      result.add(s + explain);
    }

    // مالی شخصی — با توضیح
    if (health.healthLabel == 'کسری') {
      final ratio = health.monthIncome == 0 ? 0 : (health.monthExpense / health.monthIncome * 100).round();
      result.add('💸 این ماه ${PersianFormat.money(health.net.abs())} کسری داری — هزینه‌ها ${PersianFormat.digits(ratio)}٪ درآمدت شده، یک دسته رو کم کن (چون تراز منفیه)');
    } else if (health.healthLabel == 'سالم' && health.net > 0) {
      result.add('💰 تراز ماهت ${PersianFormat.money(health.net)} مثبت — چون ${PersianFormat.digits(((health.net / (health.monthIncome == 0 ? 1 : health.monthIncome))*100).round())}٪ درآمدت مونده، ${PersianFormat.money((health.net * 0.3).round())} رو پس‌انداز کن');
    }

    if (health.anomaly != null) {
      final inc = health.anomaly!.increasePercent;
      final pct = inc.isInfinite ? 'چند برابر' : '${PersianFormat.digits(((inc - 1)*100).round())}٪';
      result.add('⚠️ هزینه «${health.anomaly!.category}» جهش کرده — ${pct} بیشتر از ماه قبل (چون ${PersianFormat.money(health.anomaly!.currentAmount)} vs ${PersianFormat.money(health.anomaly!.previousAmount)})');
    }

    // بدهی شخصی
    if (debtPlan != null && debtPlan.totalRemaining > 0) {
      if (!debtPlan.feasible) {
        result.add('🚨 بدهی‌ات با روند فعلی تا مهلت نمی‌رسه — روزی ${PersianFormat.money(debtPlan.requiredDailyEarning)} لازم داری');
      } else if (workProfile.hasEnoughData) {
        final payoff = debtPlan.estimatedPayoffDate;
        if (payoff != null) {
          result.add('✅ با روند فعلی بدهی‌هات ${PersianFormat.jalaliDate(payoff)} تموم میشه');
        }
      }
    }

    // ارزش زمان شخصی
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isNotEmpty && workProfile.avgHourlyRate > 0) {
      // گران‌ترین کار
      open.sort((a, b) => a.estimatedMinutes.compareTo(b.estimatedMinutes));
      final quickWin = open.first;
      if (quickWin.estimatedMinutes <= 20) {
        result.add('⚡ سریع‌ترین برد: «${quickWin.title}» فقط ${PersianFormat.minutes(quickWin.estimatedMinutes)} — همین الان ببندش');
      }
    }

    // عمق مالی: جریان نقدی، دوام موجودی و ثبات درآمد
    result.addAll(financeInsights.cashflowInsights(finance.transactions).take(2));

    if (result.isEmpty) {
      result.add('برای توصیه شخصی، چند روز فعالیت ثبت کن تا بشناسمت');
    }

    return result.take(5).toList();
  }

  String _nextAction({
    required List<Task> tasks,
    required AdvancedHabitProfile habitProfile,
    required FinanceHealth health,
    required RepaymentPlan? debtPlan,
  }) {
    final overdue = tasks.where((t) => t.isOverdue).length;
    if (overdue > 0) return 'اول ${PersianFormat.digits(overdue)} کار عقب‌افتاده رو ببند';
    
    // بدهی فوری
    if (debtPlan != null && debtPlan.horizonDays <= 3 && debtPlan.totalRemaining > 0) {
      return 'پرداخت بدهی فوری: ${debtPlan.priority.first.personName}';
    }

    // کسری مالی
    if (health.healthLabel == 'کسری') return 'هزینه‌ها رو کم کن یا یه کار درآمدزا انجام بده';

    // streak
    if (habitProfile.streakDays == 0 && habitProfile.hasEnoughData) {
      return 'یه کار کوچک ۱۵ دقیقه‌ای ببند تا استریک برگرده';
    }

    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) return 'کار جدید بساز یا استراحت کن';
    
    // بهترین کار
    return '«${open.first.title}» رو شروع کن';
  }
}
