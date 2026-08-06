import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../models/work_time_settings.dart';
import '../utils/persian_format.dart';
import 'advanced_habit_learning_service.dart';
import 'debt_repayment_planner.dart';
import 'finance_insights_service.dart';
import 'finance_repository.dart';
import 'forecast_service.dart';
import 'persian_nlu.dart';
import 'smart_planner.dart';
import 'time_aware_planner.dart';
import 'work_learning_service.dart';

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
    this.availability,
    this.debts,
    this.workProfile = WorkProfile.empty,
    this.repaymentPlanner = const DebtRepaymentPlanner(),
  });

  final FinanceRepository? finance;
  final ForecastService forecast;
  final FinanceInsightsService insights;

  /// تنظیمات ساعت کاری/تعطیلات کاربر (از تنظیمات برنامه).
  /// اگر null باشد، دستیار با پنجرهٔ پیش‌فرض ۹ تا ۱۸ برنامه می‌چیند.
  final WorkTimeSettings? availability;

  /// بدهی‌های فعال کاربر (برای برنامهٔ پرداخت).
  final List<DebtItem>? debts;

  /// پروفایل کاریِ یادگرفته‌شده از سابقه (برای امکان‌سنجی پرداخت).
  final WorkProfile workProfile;

  /// موتور محاسبهٔ برنامهٔ پرداخت.
  final DebtRepaymentPlanner repaymentPlanner;
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
        _context = context,
        _timeAware = context.availability == null
            ? null
            : TimeAwarePlanner(planner: planner);

  final SmartPlanner _planner;
  final AssistantContext _context;

  /// برنامه‌ریزی با رعایت ساعت کاری/تعطیلات کاربر (اگر تنظیم شده باشد).
  final TimeAwarePlanner? _timeAware;

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
      id: 'repayment_plan',
      priority: 65,
      patterns: [
        'بدهیهام کی تموم',
        'بدهیهام کی تموم میشه',
        'کی تموم میشه',
        'برنامه پرداخت',
        'برنامه پرداخت بدهی',
        'چقدر کار کنم تا',
        'قسط',
        'قسط ها',
        'قسطها',
        'تا ماه آینده',
        'پرداخت بدهی',
        'میتونم پرداخت کنم',
        'میتونم پس بدم',
        'اول کدوم بدهی',
        'کدوم بدهی اول',
        'الویت بدهی',
        'اولویت بدهی',
        'کی میتونم بدم',
        'کی میتونم پرداخت کنم',
        'بدهیام',
      ],
    ),
    NluIntent(
      id: 'habit_analysis',
      priority: 62,
      patterns: [
        'عادت هام',
        'عادتام',
        'عادتهام',
        'تحلیل عادت',
        'عادتم چطوره',
        'رفتارم چطوره',
        'الگوهام',
        'الگوي کارم',
        'چقدر منظمم',
        'یادگیری عادت',
        'عادت کاری',
        'کارام چطور پیش میره',
      ],
    ),
    NluIntent(
      id: 'prediction',
      priority: 60,
      patterns: [
        'پیش بینی',
        'پیش‌بینی',
        'پیشبینی',
        'ماه بعد',
        'ماه آینده',
        'ماه اينده چقدر',
        'هزینه ماه بعد',
        'درآمد ماه بعد',
        'پیش بینی هزینه',
        'پیش بینی درآمد',
        'ماه بعد چقدر خرج',
        'ماه بعد چقدر در میارم',
      ],
    ),
    NluIntent(
      id: 'habit_suggestion',
      priority: 58,
      patterns: [
        'پیشنهاد بده',
        'چی پیشنهاد میدی',
        'چه پیشنهادی داری',
        'چیکار کنم بهتر شم',
        'چطور بهتر شم',
        'توصیه برام',
        'نصیحت',
        'راهکار بده',
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
      case 'repayment_plan':
        return _repaymentPlan();
      case 'habit_analysis':
        return _habitAnalysis(tasks);
      case 'prediction':
        return _prediction();
      case 'habit_suggestion':
        return _habitSuggestion(tasks);
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
        '• «جبران» — برنامهٔ جبران عقب‌ماندگی\n'
        '• «عادت‌هام چطوره؟» — تحلیل عادت و استریک\n'
        '• «ماه بعد چقدر خرج می‌کنم؟» — پیش‌بینی مالی هوشمند\n'
        '• «پیشنهاد بده» — پیشنهاد خودکار بر اساس رفتارت';
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
    // اگر ساعت کاری/تعطیلات کاربر تنظیم شده باشد، با رعایت آن برنامه می‌چینیم.
    final timeAware = _timeAware;
    final availability = _context.availability;
    if (timeAware != null && availability != null) {
      final plan = timeAware.buildWorkWindowPlan(
        tasks: tasks,
        settings: availability,
      );
      if (plan.isEmpty) {
        if (availability.isOffDay(DateTime.now())) {
          return 'امروز طبق تنظیماتت روز تعطیل است؛ برنامه‌ای نمی‌چینم. استراحتت را بکن. 😌';
        }
        return 'برای امروز برنامهٔ قابل چیدن ندارم؛ یا زمان کاری تمام شده یا کاری ثبت نشده.';
      }
      return 'برنامهٔ امروز (با رعایت ساعت کاری $startEndLabel):\n${plan.take(8).map((item) => '${PersianFormat.time(item.start)} تا ${PersianFormat.time(item.end)} — ${item.task.title}').join('\n')}';
    }

    final plan = _planner.buildTodayPlan(tasks);
    if (plan.isEmpty) {
      return 'برای امروز برنامهٔ قابل چیدن ندارم؛ یا زمان روز تمام شده یا کاری ثبت نشده.';
    }
    return 'برنامهٔ امروز:\n${plan.take(8).map((item) => '${PersianFormat.time(item.start)} تا ${PersianFormat.time(item.end)} — ${item.task.title}').join('\n')}';
  }

  String get startEndLabel {
    final a = _context.availability;
    if (a == null) return '۹ تا ۱۸';
    return '${PersianFormat.digits(a.startHour)} تا ${PersianFormat.digits(a.endHour)}';
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

  /// پاسخ «حل مسئلهٔ پرداخت بدهی» با استفاده از سابقهٔ کاربر.
  String _repaymentPlan() {
    final debts = _context.debts;
    if (debts == null || debts.isEmpty) {
      return 'بدهی فعالی نداری که برنامهٔ پرداخت برایش بچینم. اگر بدهی داری، بگو: «به ممد دو میلیون بدهکارم تا آخر ماه».';
    }

    final profile = _context.workProfile;
    final planner = _context.repaymentPlanner;

    final plan = planner.plan(
      debts: debts
          .map((d) => RepaymentDebt(
                personName: d.personName,
                amount: d.remainingAmount,
                dueAt: d.dueAt,
              ))
          .toList(),
      profile: profile,
    );

    if (plan.totalRemaining <= 0) {
      return 'مجموع باقی‌ماندهٔ بدهی‌هایت صفر است؛ همه چیز پرداخت شده. 🎉';
    }

    final buffer = StringBuffer()
      ..writeln('مجموع بدهی‌هایت: ${PersianFormat.money(plan.totalRemaining)}.')
      ..writeln('اولویت پرداخت:')
      ..writeln(plan.priority
          .take(5)
          .map((d) => '${PersianFormat.digits(d.rank)}. ${d.personName} — ${PersianFormat.money(d.amount)} (${PersianFormat.digits(d.daysLeft)} روز مانده)')
          .join('\n'));

    // محاسبهٔ نیاز روزانه
    buffer
      ..writeln('تا فوری‌ترین مهلت (${plan.horizonLabel}) باید روزی حدود ${PersianFormat.money(plan.requiredDailyEarning)} در بیاوری.');

    // با درآمد ساعتی یادگرفته‌شده
    if (profile.avgHourlyRate > 0) {
      buffer.writeln('با میانگین درآمد ساعتی ${PersianFormat.money(profile.avgHourlyRate.round())}، یعنی حدود ${plan.requiredHoursLabel} کار در روز.');

      if (plan.feasible) {
        buffer.writeln('✅ شدنی است.');
      } else {
        buffer.writeln('⚠️ با ساعت‌های معقول (تا ${PersianFormat.digits(DebtRepaymentPlanner.maxReasonableHoursPerDay.round())} ساعت در روز) نمی‌رسد؛ یا مهلت را تمدید کن یا بدهی را بازپرداخت جزئی کن.');
      }
    } else {
      buffer.writeln('برای دقیق‌تر شدن محاسبه، چند کار درآمدزا را با زمان واقعی ثبت کن تا درآمد ساعتی‌ات را یاد بگیرم.');
    }

    // تاریخ پایان با توان یادگرفته‌شده
    if (profile.hasEnoughData && profile.dailyEarningCapacity > 0) {
      final payoff = plan.estimatedPayoffDate;
      if (payoff != null) {
        buffer.writeln('با روند فعلیات (${PersianFormat.minutes(profile.avgDailyWorkMinutes.round())} کار در روز ≈ ${PersianFormat.money(profile.dailyEarningCapacity.round())} درآمد روزانه)، همهٔ بدهی‌ها حدود ${PersianFormat.jalaliDate(payoff)} تموم می‌شود.');
      }
    } else if (!plan.feasible && profile.hasEnoughData) {
      buffer.writeln('برای رسیدن باید روزی حدود ${PersianFormat.digits((plan.requiredHoursPerDay).toStringAsFixed(0))} ساعت کار کنی — بیشتر از روند فعلیات.');
    }

    return buffer.toString();
  }

  String _habitAnalysis(List<Task> tasks) {
    final finance = _context.finance;
    if (finance == null) return 'برای تحلیل عادت باید به دادهٔ مالی وصل باشم.';
    final svc = const AdvancedHabitLearningService();
    final profile = svc.analyze(tasks: tasks, transactions: finance.transactions);
    if (!profile.hasEnoughData) {
      return 'هنوز داده کافی ندارم — حداقل ۳ کار تکمیل کن تا الگوهات رو یاد بگیرم. فعلا: ${svc.dashboardSummary(profile)}';
    }
    final buf = StringBuffer()
      ..writeln('📊 تحلیل عادت‌های تو:')
      ..writeln('• نرخ تکمیل: ${PersianFormat.digits((profile.completionRate * 100).round())}٪ (${PersianFormat.digits(profile.totalCompleted)} از ${PersianFormat.digits(profile.totalCompleted + profile.totalOpen)})')
      ..writeln('• استریک فعلی: ${PersianFormat.digits(profile.streakDays)} روز متوالی')
      ..writeln('• میانگین: ${PersianFormat.digits(profile.avgTasksPerDay.toStringAsFixed(1))} کار در روز')
      ..writeln('• روند: ${profile.productivityTrend > 0 ? '📈 صعودی (+${PersianFormat.digits((profile.productivityTrend * 100).round())}٪ نسبت به هفته قبل)' : profile.productivityTrend < 0 ? '📉 نزولی (${PersianFormat.digits((profile.productivityTrend * 100).round())}٪)' : '➡️ ثابت'}');
    if (profile.bestHours.isNotEmpty) {
      buf.writeln('• بهترین ساعت کاریت: ${profile.bestHours.take(2).map((h) => '${PersianFormat.digits(h)}:۰۰').join(' و ')}');
    }
    if (profile.bestWeekday != null) {
      buf.writeln('• بهترین روز هفته: ${_weekdayFa(profile.bestWeekday!)}');
    }
    for (final ch in profile.categoryHabits.take(2)) {
      buf.writeln('• ${ch.insight}');
    }
    if (profile.weeklyTrend.isNotEmpty) {
      buf.writeln('• روند ۴ هفته اخیر: ${profile.weeklyTrend.map((e) => PersianFormat.digits(e)).join(' → ')} کار');
    }
    return buf.toString();
  }

  String _prediction() {
    final finance = _context.finance;
    if (finance == null) return 'برای پیش‌بینی باید به دادهٔ مالی وصل باشم.';
    final svc = const AdvancedHabitLearningService();
    // نیاز به tasks هم داریم ولی برای پیش‌بینی مالی فقط transactions کافیه
    final profile = svc.analyze(tasks: const [], transactions: finance.transactions);
    if (profile.predictedMonthlyExpense == 0 && profile.predictedMonthlyIncome == 0) {
      return 'هنوز تراکنش کافی برای پیش‌بینی ندارم — چند هزینه و درآمد ثبت کن.';
    }
    final buf = StringBuffer()..writeln('🔮 پیش‌بینی ماه آینده (بر اساس میانگین وزنی ۳ ماه):');
    buf.writeln('• هزینه: حدود ${PersianFormat.money(profile.predictedMonthlyExpense)}');
    buf.writeln('• درآمد: حدود ${PersianFormat.money(profile.predictedMonthlyIncome)}');
    final net = profile.predictedMonthlyIncome - profile.predictedMonthlyExpense;
    if (net > 0) {
      buf.writeln('• تراز: ${PersianFormat.money(net)} مثبت ✅');
    } else if (net < 0) {
      buf.writeln('• تراز: ${PersianFormat.money(net.abs())} کسری ⚠️ — باید هزینه رو کم یا درآمد رو زیاد کنی');
    }
    return buf.toString();
  }

  String _habitSuggestion(List<Task> tasks) {
    final finance = _context.finance;
    if (finance == null) return 'برای پیشنهاد باید به دادهٔ مالی وصل باشم.';
    final svc = const AdvancedHabitLearningService();
    final profile = svc.analyze(tasks: tasks, transactions: finance.transactions);
    final sug = svc.suggestions(profile);
    return '💡 پیشنهادهای هوشمند بر اساس عادت‌هات:\n${sug.map((s) => '• $s').join('\n')}';
  }

  String _weekdayFa(int w) {
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
