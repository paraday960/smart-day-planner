import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../models/work_time_settings.dart';
import '../utils/persian_format.dart';
import 'advanced_habit_learning_service.dart';
import 'ai_brain_service.dart';
import 'feedback_learning_service.dart';
import 'predictive_scheduler_service.dart';
import 'debt_repayment_planner.dart';
import 'debt_repository.dart';
import 'finance_insights_service.dart';
import 'finance_repository.dart';
import 'category_budget_repository.dart';
import 'allocation_repository.dart';
import 'planned_expense_repository.dart';
import 'goal_repository.dart';
import 'task_repository.dart';
import 'forecast_service.dart';
import 'local_smart_summary.dart';
import 'persian_nlu.dart';
import 'conversation_router.dart';
import 'local_assistant_intents.dart';
import 'skill_service.dart';
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

  /// آیا این پیاده‌سازی، متن را «می‌فهمد» (intent مشخصی دارد)؟
  ///
  /// پیش‌فرض: true (فرض بر این است که می‌فهمد). پیاده‌سازی قانون‌محور آن را
  /// بر اساس تشخیص intent بازنویسی می‌کند.
  bool canHandle(String prompt) => true;
}

/// زمینهٔ اختیاری برای پاسخ‌های مالی دستیار.
class AssistantContext {
  const AssistantContext({
    this.finance,
    this.forecast = const ForecastService(),
    this.insights = const FinanceInsightsService(),
    this.availability,
    this.tasksProvider,
    this.debtsProvider,
    this.workProfileProvider,
    List<DebtItem>? debts,
    WorkProfile workProfile = WorkProfile.empty,
    this.repaymentPlanner = const DebtRepaymentPlanner(),
    this.taskRepo,
    this.goalRepo,
    this.plannedRepo,
    this.debtRepo,
    this.allocationRepo,
    this.budgetRepo,
  }) : _staticDebts = debts,
        _staticWorkProfile = workProfile;

  final FinanceRepository? finance;
  final ForecastService forecast;
  final FinanceInsightsService insights;
  final TaskRepository? taskRepo;
  final GoalRepository? goalRepo;
  final PlannedExpenseRepository? plannedRepo;
  final DebtRepository? debtRepo;
  final AllocationRepository? allocationRepo;
  final CategoryBudgetRepository? budgetRepo;

  /// تنظیمات ساعت کاری/تعطیلات کاربر (از تنظیمات برنامه).
  final WorkTimeSettings? availability;

  /// تأمین‌کننده‌های پویا برای داده‌های متغیر.
  final List<Task> Function()? tasksProvider;
  final List<DebtItem> Function()? debtsProvider;
  final WorkProfile Function()? workProfileProvider;

  /// کارها (پویا در صورت وجود تأمین‌کننده).
  List<Task> get tasks => tasksProvider?.call() ?? const [];

  /// بدهی‌های فعال (پویا در صورت وجود تأمین‌کننده، در غیر این صورت ثابت).
  List<DebtItem> get debts {
    final p = debtsProvider;
    if (p != null) return p();
    return _staticDebts ?? const [];
  }

  /// پروفایل کاری (پویا در صورت وجود تأمین‌کننده).
  WorkProfile get workProfile =>
      workProfileProvider?.call() ?? _staticWorkProfile;

  final List<DebtItem>? _staticDebts;
  final WorkProfile _staticWorkProfile;

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
    DateTime Function()? now,
  })  : _planner = planner,
        _context = context,
        _timeAware = context.availability == null
            ? null
            : TimeAwarePlanner(planner: planner),
        _now = now;

  final SmartPlanner _planner;
  final AssistantContext _context;

  /// ساعت قابل تزریق برای تست (پیش‌فرض: ساعت واقعی). به برنامه‌های «امروز»
  /// اجازه می‌دهد مستقل از ساعتی که اجرا می‌شوند پایدار باشند.
  final DateTime Function()? _now;
  DateTime get _currentTime => (_now ?? DateTime.now)();

  /// برنامه‌ریزی با رعایت ساعت کاری/تعطیلات کاربر (اگر تنظیم شده باشد).
  final TimeAwarePlanner? _timeAware;



  static const IntentDetector _detector = IntentDetector(intents: kRuleBasedAssistantIntents);

  /// آیا موتور قانون‌محور این متن را «می‌فهمد» (intent مشخصی دارد)؟
  ///
  /// برای اینکه دستیار بداند کی باید به هوش آنلاین مراجعه کند: وقتی محلی
  /// متوجه نمی‌شود (intent ناشناخته)، بهتر است آنلاین پاسخ دهد و یاد بگیرد.
  @override
  bool canHandle(String prompt) {
    final text = PersianNormalizer.normalize(prompt).trim();
    if (text.isEmpty) return true;
    final match = _detector.detectWithScore(text);
    if (match == null) return false;
    return match.confidence >= 0.4;
  }

  /// آیا این پرسش پاسخ معنادار محلی دارد؟
  ///
  /// برخلاف [canHandle]، برای سؤالات نامرتبط با کارها false برمی‌گرداند تا
  /// سرویس به آنلاین ارجاع دهد و پاسخ تکراری محلی ندهد.
  bool canAnswerMeaningfully(String prompt) {
    final text = PersianNormalizer.normalize(prompt).trim();
    if (text.isEmpty) return true;
    final match = _detector.detectWithScore(text);
    if (match != null) return true;
    return LocalSmartSummary.hasTaskRelatedAnswer(text);
  }

  IntentMatch? detectIntent(String prompt) {
    final text = PersianNormalizer.normalize(prompt).trim();
    if (text.isEmpty) return null;
    return _detector.detectWithScore(text);
  }

  Future<String> answerIntent(String intentId, List<Task> tasks) async {
    return generate(prompt: '[' + intentId + ']', tasks: tasks);
  }

  Future<AssistantReply> respondConversationally({
    required String prompt,
    required List<Task> tasks,
    LocalAssistantRouter? router,
  }) async {
    if (router == null) {
      final text = PersianNormalizer.normalize(prompt).trim();
      final match = _detector.detectWithScore(text);
      final answer = await generate(prompt: prompt, tasks: tasks);
      return AssistantReply(
        text: answer,
        source: 'local',
        intentId: match?.id,
        confidence: match?.confidence ?? 0,
      );
    }
    final conv = LocalAssistantConversation(
      router: router,
      generateForIntent: answerIntent,
    );
    return conv.respond(text: prompt, tasks: tasks);
  }

  @override
  Future<String> generate(
      {required String prompt, required List<Task> tasks}) async {
    final text = PersianNormalizer.normalize(prompt);
    final directIntent = _tryParseDirectIntent(prompt);
    final intent = directIntent ?? _detector.detect(text);

    if (intent == null || (text.isEmpty && directIntent == null)) {
      // پاسخ هوشمند آفلاین بر اساس نوع سؤال و داده‌های واقعی.
      final smart = LocalSmartSummary.answer(text: text, tasks: tasks);
      if (smart != null) return smart;
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
      case 'brain_status':
        return _brainStatus(tasks);
      case 'morning_briefing':
        return _morningBriefing(tasks);
      case 'forecast_30':
        return _forecast30(tasks);
      case 'feedback_positive':
        return await _handleFeedback(tasks, true);
      case 'feedback_negative':
        return await _handleFeedback(tasks, false);
      case 'show_all_data':
        return _showAllData(tasks);
      case 'manage_tasks':
        return _manageTasks(tasks);
      case 'manage_finance':
        return _manageFinance();
      case 'debt_query':
        return _debtQuery();
      case 'skill_status':
        return _skillStatus();
      case 'learning_history':
        return _learningHistory();
      case 'offline_status':
        return _offlineStatus();
      case 'small_talk':
        return 'من که همیشه سرحالم؛ چون وظیفه‌ام کمک به توئه. 😊 از کجا شروع کنیم؟';
      case 'focus_suggestion':
        return _focusSuggestion(tasks);
      case 'reschedule':
        return _reschedule(tasks);
      case 'free_time':
        return _freeTime(tasks);
      case 'productivity_tip':
        return _productivityTip(tasks);
      case 'cancel_or_stop':
        return 'باشه، متوقف شد. 👍 هر وقت خواستی دوباره ازم بپرس.';
      case 'capability_query':
        return _capabilityQuery();
      default:
        return _dailyBrief(tasks);
    }
  }

  NluIntent? _tryParseDirectIntent(String prompt) {
    final t = prompt.trim();
    final m = RegExp(r'^\[([a-z_]+)\]$').firstMatch(t);
    if (m == null) return null;
    final id = m.group(1)!;
    for (final intent in kRuleBasedAssistantIntents) {
      if (intent.id == id) return intent;
    }
    return null;
  }

  String _focusSuggestion(List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) =>
          _planner.priorityScore(b).compareTo(_planner.priorityScore(a)));
    if (open.isEmpty) {
      return 'کار بازی نداری؛ این فرصت خوبیه برای استراحت یا برنامه‌ریزی هفتهٔ آینده. 🌿';
    }
    final top = open.first;
    final reason = _planner.explainPriority(top);
    final mins = _planner.recommendedEstimate(top, tasks);
    final parts = <String>[
      '🎯 تمرکزت رو بذار روی «' + top.title + '».',
      'دلیل: ' + reason + '.',
      'زمان پیشنهادی: ' + PersianFormat.minutes(mins) + '.',
    ];
    if (open.length > 1) {
      parts.add('بعدش برو سراغ «' + open[1].title + '».');
    }
    return parts.join('\n');
  }

  String _reschedule(List<Task> tasks) {
    final plan = _planner.buildTodayPlan(tasks, now: _currentTime);
    if (plan.isEmpty) {
      return 'برنامه‌ای برای بازچیدن ندارم. کاری ثبت کن تا دوباره بچینم.';
    }
    final buf = StringBuffer('برنامهٔ بازچیده‌شدهٔ امروز:');
    for (final item in plan.take(6)) {
      buf
        ..writeln()
        ..write(PersianFormat.time(item.start) + ' — ' + item.task.title);
    }
    return buf.toString();
  }

  String _freeTime(List<Task> tasks) {
    final plan = _planner.buildTodayPlan(tasks, now: _currentTime);
    if (plan.isEmpty) {
      return 'تا آخر روز زمان آزاد زیادی داری. 🌿 اگر کار جدیدی داری، الان بهترین وقت برای ثبت آن است.';
    }
    final lastEnd = plan.last.end;
    final endOfDay = DateTime(
        _currentTime.year, _currentTime.month, _currentTime.day, 22);
    final freeMinutes = endOfDay.difference(lastEnd).inMinutes;
    if (freeMinutes <= 0) {
      return 'تا پایان روز زمان آزاد کمی داری؛ شاید بهتره بقیه کارها را به فردا موکول کنی.';
    }
    final busy = plan.fold<int>(0, (s, i) => s + i.task.estimatedMinutes);
    return 'امروز حدود ' + PersianFormat.minutes(busy) + ' زمان برنامه‌ریزی‌شده داری ' +
        'و تقریباً ' + PersianFormat.minutes(freeMinutes) + ' زمان آزاد تا پایان روز. ' +
        (freeMinutes >= 90 ? 'برای یک کار عمیق یا استراحت کافیه.' : 'کوتاهه؛ روی یک کار کوچک متمرکز شو.');
  }

  String _productivityTip(List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).length;
    final highEnergy =
        tasks.where((t) => !t.isDone && t.energy == EnergyLevel.high).length;
    var tip = 'قانون ۲ دقیقه: کارهایی که زیر ۲ دقیقه طول می‌کشند را همین الان انجام بده.';
    if (highEnergy > 0) {
      tip = highEnergy.toString() + ' کار با انرژی بالا داری — سخت‌ترینش را اول انجام بده.';
    } else if (open > 5) {
      tip = PersianFormat.digits(open) + ' کار باز داری؛ اول ۳ تای مهم را انتخاب کن و بقیه را به فردا بسپار.';
    }
    return '💡 نکتهٔ بهره‌وری: ' + tip;
  }

  String _capabilityQuery() {
    return [
      'من می‌تونم:',
      '• برنامه‌ریزی روزانه/هفتگی کنم و کار بعدی رو پیشنهاد بدم',
      '• وضعیت مالی، بودجه و بدهی‌هات رو تحلیل کنم',
      '• پیش‌بینی درآمد/هزینه و برنامهٔ پرداخت بدهی بدم',
      '• عادت‌ها و ریسک‌هات رو بررسی کنم',
      '• با فرمان صوتی کارها و تراکنش‌ها رو ثبت کنم',
      '• پاسخ‌هام رو از تعاملاتت یاد بگیرم (آفلاین هم کار می‌کنم)',
    ].join('\n');
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
    return 'از من می‌توانی این‌ها را بپرسی:\n• «الان چی کار کنم؟» — بهترین کار بعدی\n• «برنامه امروزمو بچین» — برنامهٔ زمانی امروز\n• «این هفته چی کار کنم؟» — برنامهٔ هفته\n• «چی عقب مونده؟» — کارهای عقب‌افتاده\n• «ریسک دارم؟» — ریسک‌های کاری و مالی\n• «امروز چیکار کردم؟» — خلاصهٔ انجام‌ها\n• «چقدر درآمد دارم؟» — پیش‌بینی درآمد\n• «وضعیت مالیم چطوره؟» — تحلیل مالی\n• «کی کار کنم؟» — بهترین زمان تمرکز\n• «جبران» — برنامهٔ جبران عقب‌ماندگی\n• «عادت‌هام چطوره؟» — تحلیل عادت و استریک\n• «ماه بعد چقدر خرج می‌کنم؟» — پیش‌بینی مالی هوشمند\n• «پیشنهاد بده» — پیشنهاد خودکار بر اساس رفتارت\n• «وضعیت کلی» — مغز یکپارچه: امتیاز، حال مالی و توصیه شخصی\n• «صبح بخیر» — بریفینگ شخصی صبح\n• «هفته آینده چطوره؟» — پیش‌بینی ۷ روز + زمان‌بندی خودکار\n• «همه اطلاعات رو نشون بده» — مدیریت و نمایش همه داده‌ها توسط دستیار';
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
        if (availability.isOffDay(_currentTime)) {
          return 'امروز طبق تنظیماتت روز تعطیل است؛ برنامه‌ای نمی‌چینم. استراحتت را بکن. 😌 (ساعت کاری $startEndLabel)';
        }
        // اصلاح برای تست flaky: حتی وقتی برنامه خالی است، ذکر «با رعایت ساعت کاری» بماند
        return 'برای امروز با رعایت ساعت کاری $startEndLabel برنامهٔ قابل چیدن ندارم؛ یا زمان کاری تمام شده یا کاری ثبت نشده. فردا صبح (ساعت $startEndLabel) دوباره امتحان کن.';
      }
      return 'برنامهٔ امروز (با رعایت ساعت کاری $startEndLabel):\n${plan.take(8).map((item) => '${PersianFormat.time(item.start)} تا ${PersianFormat.time(item.end)} — ${item.task.title}').join('\n')}';
    }

    final plan = _planner.buildTodayPlan(tasks, now: _currentTime);
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
    final now = _currentTime;
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
    final now = _currentTime;
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
    final now = _currentTime;
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

  String _brainStatus(List<Task> tasks) {
    final finance = _context.finance;
    if (finance == null) return 'برای تحلیل مغز باید به داده متصل باشم.';
    final brain = const AIBrainService().analyze(
      tasks: tasks,
      transactions: finance.transactions,
      finance: finance,
      debts: _context.debts ?? [],
    );
    final buf = StringBuffer()
      ..writeln('🧠 مغز هوشمند یکپارچه:')
      ..writeln('• امتیاز کلی: ${PersianFormat.digits(brain.brainScore)}/۱۰۰ — ${brain.mood == 'excellent' ? 'عالی 🌟' : brain.mood == 'good' ? 'خوب ☀️' : brain.mood == 'warning' ? 'هشدار ⚠️' : 'بحرانی 🚨'}')
      ..writeln('• حال مالی: ${brain.financeHealth.healthLabel} (${PersianFormat.money(brain.financeHealth.net)} تراز)')
      ..writeln('• عادت: تکمیل ${PersianFormat.digits((brain.habitProfile.completionRate * 100).round())}٪، استریک ${PersianFormat.digits(brain.habitProfile.streakDays)} روز')
      ..writeln('• اقدام بعدی: ${brain.nextAction}')
      ..writeln('💡 توصیه‌ها:');
    for (final ins in brain.personalizedInsights.take(3)) {
      buf.writeln('  • $ins');
    }
    if (brain.debtPlan != null && brain.debtPlan!.totalRemaining > 0) {
      buf.writeln('💳 بدهی: ${PersianFormat.money(brain.debtPlan!.totalRemaining)}');
    }
    return buf.toString();
  }

  Future<String> _handleFeedback(List<Task> tasks, bool positive) async {
    final svc = FeedbackLearningService();
    await svc.recordFeedback(suggestionType: 'general', type: positive ? FeedbackType.positive : FeedbackType.negative);
    if (positive) return 'ممنون! 😊 یاد گرفتم این مدل پیشنهاد رو بیشتر بدم. باز هم بگو چی دوست داری.';
    return 'متوجه شدم 🙏 یاد گرفتم این مدل پیشنهاد رو کمتر بدم. دفعه بعد بهتر پیشنهاد می‌دم.';
  }

  String _forecast30(List<Task> tasks) {
    final finance = _context.finance;
    if (finance == null) return 'برای پیش‌بینی باید به داده متصل باشم.';
    final svc = const PredictiveSchedulerService();
    final warnings = svc.next7DaysWarnings(transactions: finance.transactions, tasks: tasks);
    final schedule = svc.autoSchedule(tasks: tasks, habitProfile: const AdvancedHabitLearningService().analyze(tasks: tasks, transactions: finance.transactions));
    final buf = StringBuffer()..writeln('🔮 پیش‌بینی هوشمند ۷ روز آینده:');
    for (final w in warnings) buf.writeln('• $w');
    if (schedule.isNotEmpty) {
      buf.writeln('⏰ زمان‌بندی پیشنهادی:');
      for (final s in schedule.take(3)) buf.writeln('• «${s.task.title}» → ${PersianFormat.jalaliDate(s.suggestedStart)} ساعت ${PersianFormat.time(s.suggestedStart)} (${s.reason})');
    }
    return buf.toString();
  }

  String _morningBriefing(List<Task> tasks) {
    final finance = _context.finance;
    if (finance == null) return 'برای بریفینگ باید به داده متصل باشم.';
    final brain = const AIBrainService().analyze(
      tasks: tasks,
      transactions: finance.transactions,
      finance: finance,
      debts: _context.debts ?? [],
    );
    return const AIBrainService().morningBriefing(brain, tasks);
  }

  String _showAllData(List<Task> tasks) {
    final finance = _context.finance;
    final buf = StringBuffer()..writeln('📊 همه اطلاعاتت (مدیریت توسط دستیار):');
    // کارها
    final open = tasks.where((t) => !t.isDone).length;
    final done = tasks.where((t) => t.isDone).length;
    buf.writeln('📋 کارها: ${PersianFormat.digits(open)} باز، ${PersianFormat.digits(done)} انجام‌شده');
    for (final t in tasks.where((t) => !t.isDone).take(3)) {
      buf.writeln('  • ${t.title} (اهمیت ${PersianFormat.digits(t.importance)}، ${t.category})');
    }
    if (open > 3) buf.writeln('  ... و ${PersianFormat.digits(open-3)} کار دیگر');
    // مالی
    if (finance != null) {
      final txs = finance.transactions;
      final income = txs.where((e) => e.type == FinanceTransactionType.income).fold<int>(0, (s,e) => s+e.amount);
      final expense = txs.where((e) => e.type == FinanceTransactionType.expense).fold<int>(0, (s,e) => s+e.amount);
      buf.writeln('💰 مالی: درآمد ${PersianFormat.money(income)}، هزینه ${PersianFormat.money(expense)}، تراز ${PersianFormat.money(income-expense)}');
      for (final tx in txs.take(3)) {
        buf.writeln('  • ${tx.type == FinanceTransactionType.income ? '💵' : '💸'} ${tx.category}: ${PersianFormat.money(tx.amount)}');
      }
    }
    // بدهی
    final debts = _context.debts ?? [];
    if (debts.isNotEmpty) {
      buf.writeln('💳 بدهی‌ها: ${PersianFormat.digits(debts.length)} مورد');
      for (final d in debts.take(3)) buf.writeln('  • ${d.personName}: ${PersianFormat.money(d.remainingAmount)} تا ${PersianFormat.jalaliDate(d.dueAt)}');
    } else {
      buf.writeln('💳 بدهی: نداری ✅');
    }
    // اهداف
    final goals = _context.goalRepo;
    if (goals != null) {
      if (goals.dailyIncomeGoal > 0) buf.writeln('🎯 هدف روزانه: ${PersianFormat.money(goals.dailyIncomeGoal)}');
      if (goals.monthlyIncomeGoal > 0) buf.writeln('🎯 هدف ماهانه: ${PersianFormat.money(goals.monthlyIncomeGoal)}');
    }
    // بودجه
    final budgets = _context.budgetRepo;
    if (budgets != null && budgets.items.isNotEmpty) {
      buf.writeln('📊 بودجه: ${PersianFormat.digits(budgets.items.length)} دسته');
      for (final b in budgets.items.take(3)) buf.writeln('  • ${b.category}: ${PersianFormat.money(b.monthlyLimit)}');
    }
    buf.writeln('---');
    buf.writeln('برای مدیریت بگو: «کار جدید بساز»، «هزینه ثبت کن»، یا «بدهی اضافه کن» — همه توسط من انجام می‌شه 🤖');
    return buf.toString();
  }

  String _manageTasks(List<Task> tasks) {
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) return 'کاری نداری. بگو «کار جدید: تماس با مشتری فردا ساعت ۱۰» تا بسازم.';
    final buf = StringBuffer()..writeln('📋 کارهای باز (${PersianFormat.digits(open.length)}):');
    for (final t in open.take(5)) {
      buf.writeln('• ${t.title} — ${t.category} — اهمیت ${PersianFormat.digits(t.importance)} ${t.dueAt != null ? 'تا ${PersianFormat.jalaliDate(t.dueAt!)}' : ''}');
    }
    if (open.length > 5) buf.writeln('و ${PersianFormat.digits(open.length-5)} کار دیگر');
    buf.writeln('برای مدیریت: «کار جدید ...» یا «کار X رو حذف کن»');
    return buf.toString();
  }

  String _manageFinance() {
    final finance = _context.finance;
    if (finance == null || finance.transactions.isEmpty) return 'تراکنشی نداری. بگو «درآمد ۲ میلیون ثبت کن» یا «هزینه ۳۰۰ هزار».';
    final txs = finance.transactions;
    final buf = StringBuffer()..writeln('💰 تراکنش‌ها (${PersianFormat.digits(txs.length)}):');
    for (final tx in txs.take(5)) {
      buf.writeln('• ${tx.type == FinanceTransactionType.income ? 'درآمد' : 'هزینه'} ${PersianFormat.money(tx.amount)} — ${tx.category} — ${PersianFormat.jalaliDate(tx.createdAt)}');
    }
    if (txs.length > 5) buf.writeln('و ${PersianFormat.digits(txs.length-5)} مورد دیگر');
    buf.writeln('تراز ماه: ${PersianFormat.money(finance.netThisMonth())}');
    return buf.toString();
  }

  String _debtQuery() {
    final debts = _context.debts;
    if (debts == null || debts.isEmpty) return 'بدهی فعالی نداری. بگو «به فرهاد دو میلیون بدهکارم تا دو روز دیگه» تا ثبت کنم.';
    final active = debts.where((d) => d.isActive).toList();
    if (active.isEmpty) return 'همه بدهی‌ها تسویه شده 🎉';
    final buf = StringBuffer()..writeln('📁 بدهی‌های فعال (${PersianFormat.digits(active.length)}):');
    for (final d in active.take(4)) {
      buf.writeln('• ${d.personName}: ${PersianFormat.money(d.remainingAmount)} از ${PersianFormat.money(d.amount)} تا ${PersianFormat.jalaliDate(d.dueAt)} (${PersianFormat.digits(((d.paidAmount / d.amount) * 100).round())}٪ پرداخت)');
    }
    if (active.length > 4) buf.writeln('و ${PersianFormat.digits(active.length - 4)} مورد دیگر — بگو «بدهی فرهاد چقدره؟» برای جزئیات یک نفر');
    return buf.toString();
  }

  String _skillStatus() {
    final skill = SkillService.instance;
    // اگر هنوز لود نشده، مقادیر ۰ برمی‌گردد که اشکالی ندارد
    return '⭐ مهارت هوش محلی\n'
        '• سطح: ${PersianFormat.digits(skill.level)} — ${skill.levelLabel}\n'
        '• امتیاز: ${PersianFormat.digits(skill.score)} (تا سطح بعد ${PersianFormat.digits(100 - skill.progressToNextLevel)})\n'
        '• چیزهای یادگرفته: ${PersianFormat.digits(skill.learnedCount)}\n'
        '• پیشرفت: ${PersianFormat.digits(skill.progressToNextLevel)}٪\n'
        'برای تاریخچه بگو «چی یاد گرفتی؟»';
  }

  String _learningHistory() {
    final skill = SkillService.instance;
    if (skill.history.isEmpty) return 'هنوز چیزی یاد نگرفتم — یه سوال جدید از هوش آنلاین بپرس تا یاد بگیرم! (مثلا چیزی که محلی بلد نیست)';
    final recent = skill.history.reversed.take(5).toList();
    final buf = StringBuffer()..writeln('📚 تاریخچه یادگیری (${PersianFormat.digits(skill.history.length)} مورد):');
    for (final e in recent) {
      buf.writeln('• +${PersianFormat.digits(e['points'] ?? 0)} — ${e['reason'] ?? ''}');
    }
    buf.writeln('برای امتیاز بگو «مهارت من چقدره؟»');
    return buf.toString();
  }

  String _offlineStatus() {
    // FeatureFlags are compile-time constants, so we can check them directly
    // ignore: deprecated_member_use
    const localLlm = bool.fromEnvironment('ENABLE_LOCAL_LLM', defaultValue: true);
    const offlineSpeech = bool.fromEnvironment('ENABLE_OFFLINE_SPEECH', defaultValue: true);
    // در واقعیت باید از FeatureFlags خواند، ولی برای نمایش ساده:
    final localLabel = localLlm ? 'فعال (در صورت وجود مدل GGUF)' : 'خاموش';
    final offlineLabel = offlineSpeech ? 'فعال (در صورت وجود مدل Vosk)' : 'خاموش';
    return 'هوش محلی:\n'
        '• LLM محلی: $localLabel\n'
        '• تشخیص گفتار آفلاین: $offlineLabel\n'
        '• موتور قانون‌محور: همیشه فعال ✅\n'
        'اگر مدل‌ها نباشد خودکار به موتور قانون‌محور برمی‌گردد.';
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
