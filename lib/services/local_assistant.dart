import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_insights_service.dart';
import 'finance_repository.dart';
import 'forecast_service.dart';
import 'persian_nlu.dart';
import 'smart_planner.dart';

/// قرارداد اتصال LLM آفلاین واقعی.
/// بعداً می‌توانی این را با llama.cpp / ONNX / TFLite پیاده‌سازی کنی.
abstract class LocalLlmAdapter {
  Future<String> generate({
    required String prompt,
    required List<Task> tasks,
  });
}

/// زمینهٔ اختیاری برای پاسخ‌های مالی دستیار.
class AssistantContext {
  const AssistantContext({
    this.finance,
    this.forecast = const ForecastService(),
    this.insights = const FinanceInsightsService(),
  });

  final FinanceRepository? finance;
  final ForecastService forecast;
  final FinanceInsightsService insights;
}

/// نسخهٔ ارتقایافتهٔ دستیار قانون‌محور (بدون هیچ LLM).
///
/// حالا به‌جای چند if ساده، از تشخیص قصد (intent detection) با
/// نرمال‌سازی فارسی و امتیازدهی الگو استفاده می‌کند و پاسخ‌های
/// متنوع‌تر و کاربردی‌تری می‌دهد.
class RuleBasedLocalAssistant implements LocalLlmAdapter {
  RuleBasedLocalAssistant({
    SmartPlanner planner = const SmartPlanner(),
    AssistantContext context = const AssistantContext(),
  })  : _planner = planner,
        _context = context;

  final SmartPlanner _planner;
  final AssistantContext _context;

  static const List<NluIntent> _intents = [
    NluIntent(
      id: 'greeting',
      priority: 30,
      patterns: [
        'سلام',
        'درود',
        'صبح بخیر',
        'صبحت بخیر',
        'ظهر بخیر',
        'عصر بخیر',
        'شب بخیر',
        'سلام علیکم',
        'سلام خوبی',
      ],
    ),
    NluIntent(
      id: 'thanks',
      priority: 40,
      patterns: [
        'ممنون',
        'مرسی',
        'سپاس',
        'تشکر',
        'دمت گرم',
        'دمت',
        'دستت درد نکنه',
        'عالی بود'
      ],
    ),
    NluIntent(
      id: 'help',
      priority: 50,
      patterns: [
        'راهنما',
        'کمک',
        'چه کارهایی بلدی',
        'چه کارهایی میتونی',
        'چه چیزهایی بلدی',
        'چطور استفاده کنم',
        'چطوری استفاده کنم',
        'چطور کار کنم',
        'بلدی چیکار',
        'کمکم کن',
        'چیکار میتونی بکنی',
        'چه کارهایی انجام میدی',
      ],
    ),
    NluIntent(
      id: 'next_task',
      priority: 45,
      patterns: [
        'الان چی کار کنم',
        'الان چیکار کنم',
        'الان چی کار کنم',
        'بعدش چی',
        'بعدی چیه',
        'کار بعدی',
        'چه کاری انجام بدم',
        'چی کار کنم',
        'چیکار کنم',
        'الان شروع کنم',
        'شروع کنم',
        'اول کدوم',
        'اول کدوم رو',
        'بهترین کار بعدی',
        'حالا چی',
      ],
    ),
    NluIntent(
      id: 'today_plan',
      priority: 40,
      patterns: [
        'برنامه امروز',
        'برنامه امروزم',
        'امروز چی کار کنم',
        'امروز چیکار کنم',
        'برنامه امروزمو بچین',
        'امروز چی کار',
        'امروز چیکار',
        'زمان بندی امروز',
        'زمان‌بندی امروز',
        'زمانبندی امروز',
        'امروز چه برنامه ای',
        'برنامه من امروز',
      ],
    ),
    NluIntent(
      id: 'week_plan',
      priority: 35,
      patterns: [
        'برنامه هفته',
        'این هفته',
        'برنامه هفتگی',
        'فردا چی کار کنم',
        'فردا چیکار کنم',
        'فردا چی کار',
        'برنامه فردا',
        'این هفته چی کار کنم',
      ],
    ),
    NluIntent(
      id: 'overdue',
      priority: 60,
      patterns: [
        'چی عقب مونده',
        'چی عقب افتاده',
        'چه کارایی عقب',
        'چه کارهایی عقب',
        'کارهای عقب',
        'عقب افتاده ها',
        'چند کار دیر شده',
        'کدوم کارها دیر شده',
      ],
    ),
    NluIntent(
      id: 'risk_alerts',
      priority: 40,
      patterns: [
        'ریسک',
        'مشکل',
        'خطر',
        'بحرانی',
        'نگران',
        'عقب افتادم',
        'عقب موندم',
        'دیرم شده',
        'دارم عقب میمونم',
        'اوضاعم چطوره',
        'وضعیت روزم چطوره',
      ],
    ),
    NluIntent(
      id: 'done_today',
      priority: 35,
      patterns: [
        'امروز چه کارهایی انجام دادم',
        'امروز چیکار کردم',
        'امروز چی کار کردم',
        'چند کار تموم کردم',
        'امروز چی تموم کردم',
        'امروز چی انجام دادم',
        'کارهای انجام شده امروز',
        'امروز چند کار',
      ],
    ),
    NluIntent(
      id: 'income_forecast',
      priority: 45,
      patterns: [
        'چقدر درآمد دارم',
        'چقدر درآمد',
        'درآمد امروز',
        'درآمد فردا',
        'درآمد احتمالی',
        'میانگین درآمد',
        'درآمد ساعتی',
        'چقدر پول در میارم',
        'چقدر درامد',
        'ساعت کار درآمدزا',
      ],
    ),
    NluIntent(
      id: 'budget_status',
      priority: 40,
      patterns: [
        'بودجه',
        'سقف هزینه',
        'چقدر خرج کردم',
        'این ماه چقدر خرج',
        'این ماه چقدر هزینه',
        'خرج های این ماه',
        'هزینه های این ماه',
        'محدودیت بودجه',
      ],
    ),
    NluIntent(
      id: 'finance_advice',
      priority: 30,
      patterns: [
        'وضعیت مالیم',
        'وضعیت مالی من',
        'پولم چطوره',
        'مالیم چطوره',
        'پس اندازم',
        'چقدر پس انداز دارم',
        'پول',
        'خرج',
        'هزینه هام',
        'بهتره چیکار کنم',
        'توصیه مالی',
        'راهنمایی مالی',
      ],
    ),
    NluIntent(
      id: 'best_time',
      priority: 45,
      patterns: [
        'بهترین زمان',
        'کی کار کنم',
        'چه ساعتی کار کنم',
        'کی تمرکز کنم',
        'بهترین ساعت',
        'کی انرژی دارم',
        'چه زمانی کار کنم',
        'بهترین وقت',
        'کی کار سنگین کنم',
        'کی کار مهم کنم',
      ],
    ),
    NluIntent(
      id: 'catch_up',
      priority: 50,
      patterns: [
        'جبران',
        'خیلی کار دارم',
        'خیلی کار عقب دارم',
        'برنامه جبرانی',
        'چطوری برسم',
        'چطور برسم',
        'خیلی عقبم',
        'کارام زیاده',
        'خیلی کار دارم چیکار کنم',
      ],
    ),
    NluIntent(
      id: 'motivation',
      priority: 35,
      patterns: [
        'حوصله ندارم',
        'بی حوصله',
        'انگیزه ندارم',
        'بی انگیزه',
        'خسته ام',
        'خستم',
        'حال ندارم',
        'حوصله کار ندارم',
        'دلم نمیخواد',
        'بی حوصله ام',
      ],
    ),
    NluIntent(
      id: 'small_talk',
      priority: 20,
      patterns: ['حالت چطوره', 'چه خبر', 'خوبی', 'چطوری', 'حال و احوالت'],
    ),
  ];

  static const IntentDetector _detector = IntentDetector(intents: _intents);

  @override
  Future<String> generate(
      {required String prompt, required List<Task> tasks}) async {
    final text = PersianNormalizer.normalize(prompt);
    final intent = _detector.detect(text);

    if (intent == null || text.isEmpty) {
      return _dailyBrief(tasks);
    }

    switch (intent.id) {
      case 'greeting':
        return _greeting(tasks);
      case 'thanks':
        return 'خواهش می‌کنم! هر وقت کاری داشتی، من اینجام. 🙌';
      case 'help':
        return _help();
      case 'next_task':
        return _nextTask(tasks);
      case 'today_plan':
        return _todayPlan(tasks);
      case 'week_plan':
        return _weekPlan(tasks);
      case 'overdue':
        return _overdue(tasks);
      case 'risk_alerts':
        return _risk(tasks);
      case 'done_today':
        return _doneToday(tasks);
      case 'income_forecast':
        return _incomeForecast();
      case 'budget_status':
        return _budgetStatus();
      case 'finance_advice':
        return _financeAdvice(tasks);
      case 'best_time':
        return _bestTime(tasks);
      case 'catch_up':
        return _catchUp(tasks);
      case 'motivation':
        return _motivation(tasks);
      case 'small_talk':
        return 'من که همیشه سرحالم؛ چون وظیفه‌ام کمک به توئه. 😊 از کجا شروع کنیم؟';
      default:
        return _dailyBrief(tasks);
    }
  }

  String _greeting(List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).length;
    final plan = _planner.buildTodayPlan(tasks);
    final top = plan.isNotEmpty ? plan.first.task : null;
    final parts = <String>[
      'سلام! 👋 امروز ${PersianFormat.digits(open)} کار باز داری.',
    ];
    if (top != null) {
      parts.add('پیشنهاد من: با «${top.title}» شروع کن.');
    }
    if (plan.isNotEmpty) {
      parts.add(
          'کل برنامهٔ امروز ${PersianFormat.digits(plan.length)} کار است.');
    }
    return parts.join('\n');
  }

  String _help() {
    return 'از من می‌توانی این‌ها را بپرسی:\n'
        '• «الان چی کار کنم؟» — بهترین کار بعدی\n'
        '• «برنامه امروزمو بچین» — برنامهٔ زمانی امروز\n'
        '• «این هفته چی کار کنم؟» — برنامهٔ هفته\n'
        '• «چی عقب مونده؟» — کارهای عقب‌افتاده\n'
        '• «ریسک دارم؟» — ریسک‌های کاری و مالی\n'
        '• «امروز چیکار کردم؟» — خلاصهٔ انجام‌ها\n'
        '• «چقدر درآمد دارم؟» — پیش‌بینی درآمد\n'
        '• «وضعیت مالیم چطوره؟» — تحلیل مالی\n'
        '• «کی کار کنم؟» — بهترین زمان تمرکز\n'
        '• «جبران» — برنامهٔ جبران عقب‌ماندگی';
  }

  String _nextTask(List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) {
      return 'همهٔ کارها انجام شده! 🎉 کار جدیدی ثبت کن یا یک استراحت کوتاه بگیر.';
    }
    final sorted = [...open]..sort((a, b) =>
        _planner.priorityScore(b).compareTo(_planner.priorityScore(a)));
    final top = sorted.first;
    final buffer = StringBuffer()
      ..writeln('پیشنهاد من: «${top.title}» رو شروع کن.')
      ..writeln('دلیل: ${_planner.explainPriority(top)}.')
      ..writeln(
          'زمان پیشنهادی: ${PersianFormat.minutes(_planner.recommendedEstimate(top, tasks))}.');
    if (sorted.length > 1) {
      buffer.write('بعد از آن: «${sorted[1].title}».');
    }
    return buffer.toString();
  }

  String _todayPlan(List<Task> tasks) {
    final plan = _planner.buildTodayPlan(tasks);
    if (plan.isEmpty) {
      return 'برای امروز برنامهٔ قابل چیدن ندارم؛ یا زمان روز تمام شده یا کاری ثبت نشده.';
    }
    return 'برنامهٔ امروز:\n${plan.take(8).map((item) => '${PersianFormat.time(item.start)} تا ${PersianFormat.time(item.end)} — ${item.task.title}').join('\n')}';
  }

  String _weekPlan(List<Task> tasks) {
    final week = _planner.buildWeekPlan(tasks);
    if (week.isEmpty) return 'کاری برای برنامه‌ریزی هفته نداری.';
    final lines = <String>[];
    for (final day in week) {
      final date = PersianFormat.jalaliDate(day.date);
      final label = day.isToday ? '$date (امروز)' : date;
      if (day.items.isEmpty) {
        lines.add('$label: آزاد');
      } else {
        lines.add(
            '$label: ${day.items.map((i) => i.task.title).take(3).join('، ')}${day.items.length > 3 ? ' و ${PersianFormat.digits(day.items.length - 3)} کار دیگر' : ''}');
      }
    }
    return 'برنامهٔ هفته:\n${lines.join('\n')}';
  }

  String _overdue(List<Task> tasks) {
    final now = DateTime.now();
    final overdue = tasks
        .where((t) => !t.isDone && t.dueAt != null && t.dueAt!.isBefore(now))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (overdue.isEmpty) return 'کار عقب‌افتاده‌ای نداری. 👍';
    final buffer = StringBuffer()
      ..writeln('${PersianFormat.digits(overdue.length)} کار عقب‌افتاده داری:')
      ..writeln(
        overdue
            .take(5)
            .map((t) =>
                '• ${t.title} (مهلت: ${PersianFormat.jalaliDate(t.dueAt!)})')
            .join('\n'),
      );
    if (overdue.length > 5) {
      buffer
          .writeln('و ${PersianFormat.digits(overdue.length - 5)} مورد دیگر.');
    }
    final total = overdue.fold<int>(
        0, (sum, t) => sum + _planner.recommendedEstimate(t, tasks));
    buffer.write(
        'جمع زمان لازم برای بستن همه: حدود ${PersianFormat.minutes(total)}. بگو «جبران» تا برنامه بدهم.');
    return buffer.toString();
  }

  String _risk(List<Task> tasks) {
    final parts = <String>[];
    final now = DateTime.now();
    final overdue = tasks
        .where((t) => !t.isDone && t.dueAt != null && t.dueAt!.isBefore(now))
        .toList();
    if (overdue.isNotEmpty) {
      parts.add(
          '${PersianFormat.digits(overdue.length)} کار عقب‌افتاده داری که ریسک‌شان بالاست.');
    }
    final nearDue = tasks.where((t) {
      final due = t.dueAt;
      return !t.isDone &&
          due != null &&
          !due.isBefore(now) &&
          due.difference(now).inHours <= 24;
    }).toList();
    if (nearDue.isNotEmpty) {
      parts.add(
          '${PersianFormat.digits(nearDue.length)} کار مهلت‌شان تا ۲۴ ساعت آینده است.');
    }

    // ریسک مالی اگر زمینه در دسترس باشد
    final finance = _context.finance;
    if (finance != null) {
      final risk = _context.insights.riskFrom(finance.transactions);
      if (risk != null && risk.isNotEmpty) {
        parts.add('ریسک مالی: $risk');
      }
    }

    if (parts.isEmpty) {
      return 'فعلاً ریسک جدی نمی‌بینم. مراقب کارهای با مهلت نزدیک باش.';
    }
    return parts.join('\n');
  }

  String _doneToday(List<Task> tasks) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final done = tasks
        .where((t) =>
            t.isDone &&
            t.completedAt != null &&
            !t.completedAt!.isBefore(startOfDay))
        .toList();
    if (done.isEmpty) {
      return 'امروز هنوز کاری را کامل نکرده‌ای. اولین کار کوچک را انتخاب کن تا شروعی داشته باشی.';
    }
    return 'امروز ${PersianFormat.digits(done.length)} کار انجام دادی:\n${done.take(8).map((t) => '• ${t.title}${t.actualMinutes != null && t.actualMinutes! > 0 ? ' (${PersianFormat.minutes(t.actualMinutes!)})' : ''}').join('\n')}';
  }

  String _incomeForecast() {
    final finance = _context.finance;
    if (finance == null) {
      return 'برای پیش‌بینی درآمد، باید به دادهٔ مالی وصل باشم. چند درآمد را با زمان واقعی ثبت کن.';
    }
    final hourly = finance.averageHourlyRate();
    if (hourly <= 0) {
      return 'هنوز میانگین درآمد ساعتی ندارم؛ چند کار درآمدزا را با زمان واقعی ثبت کن تا بتوانم پیش‌بینی کنم.';
    }
    final expected3h = (hourly * 3).round();
    final expected6h = (hourly * 6).round();
    return 'میانگین درآمد ساعتی تو: حدود ${PersianFormat.money(hourly)}.\n'
        'با ۳ ساعت کار درآمدزا: حدود ${PersianFormat.money(expected3h)}.\n'
        'با ۶ ساعت: حدود ${PersianFormat.money(expected6h)}.\n'
        'این پیش‌بینی بر اساس ${PersianFormat.digits(finance.transactions.where((t) => t.hourlyRate != null).length)} کار درآمدزای ثبت‌شده است.';
  }

  String _budgetStatus() {
    final finance = _context.finance;
    if (finance == null) return 'برای بررسی بودجه باید به دادهٔ مالی وصل باشم.';
    final monthStart = finance.currentJalaliMonthStart();
    final monthEnd = finance.currentJalaliMonthEnd();
    final expense = finance.total(
        type: FinanceTransactionType.expense, from: monthStart, to: monthEnd);
    final income = finance.total(
        type: FinanceTransactionType.income, from: monthStart, to: monthEnd);
    final categories = finance.totalsByCategory(
        type: FinanceTransactionType.expense, from: monthStart, to: monthEnd);
    final topCategory = categories.entries.isNotEmpty
        ? categories.entries.reduce((a, b) => a.value >= b.value ? a : b)
        : null;
    return 'خرج این ماه: ${PersianFormat.money(expense)}\n'
        'درآمد این ماه: ${PersianFormat.money(income)}\n'
        '${topCategory != null ? 'بیشترین هزینه در دستهٔ «${topCategory.key}»: ${PersianFormat.money(topCategory.value)}' : 'هنوز هزینه‌ای ثبت نشده.'}';
  }

  String _financeAdvice(List<Task> tasks) {
    final finance = _context.finance;
    if (finance == null) {
      return 'برای تحلیل مالی باید به دادهٔ مالی وصل باشم. فعلاً می‌توانم در مورد برنامه‌ریزی کارها کمک کنم: ${_nextTask(tasks)}';
    }
    final insights = _context.insights.advice(finance.transactions);
    if (insights.isEmpty) {
      return 'دادهٔ مالی کافی برای تحلیل نیست؛ چند تراکنش ثبت کن.';
    }
    return insights.take(4).join('\n');
  }

  String _bestTime(List<Task> tasks) {
    final windows = _planner.bestDeepWorkWindows(tasks);
    if (windows.isEmpty) {
      return 'امروز پنجرهٔ آزاد بلندی برای کار عمیق پیدا نکردم.';
    }
    return 'بهترین بازه‌های کار عمیق امروز:\n${windows.map((w) => '${PersianFormat.time(w.start)} تا ${PersianFormat.time(w.end)} — ${w.reason}').join('\n')}';
  }

  String _catchUp(List<Task> tasks) {
    final plan = _planner.catchUpPlan(tasks);
    if (plan.isEmpty) {
      return 'چیزی برای جبران نداری؛ برنامهٔ امروزت جمع‌وجور است.';
    }
    return plan.join('\n');
  }

  String _motivation(List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) {
      return 'به نظر می‌رسد همه‌چیز تمام شده؛ جای نگرانی نیست! 😊';
    }
    final shortest = [...open]
      ..sort((a, b) => a.estimatedMinutes.compareTo(b.estimatedMinutes));
    final small = shortest.first;
    return 'حسش رو درک می‌کنم. 🌱 پیشنهاد: فقط «${small.title}» را انجام بده (حدود ${PersianFormat.minutes(small.estimatedMinutes)}). '
        'شروع کوچک، مغز را به حرکت درمی‌آورد و ادامه‌اش راحت‌تر می‌شود. بعدش دوباره از من بپرس.';
  }

  String _dailyBrief(List<Task> tasks) {
    final suggestions = _planner.suggestions(tasks);
    final openCount = tasks.where((t) => !t.isDone).length;
    final doneCount = tasks.where((t) => t.isDone).length;
    final buffer = StringBuffer()
      ..writeln(
          'خلاصهٔ امروز: ${PersianFormat.digits(openCount)} کار باز و ${PersianFormat.digits(doneCount)} کار انجام‌شده.')
      ..write(suggestions.map((s) => '• $s').join('\n'));
    return buffer.toString();
  }
}
