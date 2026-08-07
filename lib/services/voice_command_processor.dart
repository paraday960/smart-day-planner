import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/money_allocation.dart';
import '../models/planned_expense_goal.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'allocation_repository.dart';
import 'command_confidence_service.dart';
import 'conversation_memory_service.dart';
import 'debt_planning_service.dart';
import 'debt_repository.dart';
import 'finance_assistant.dart';
import '../domain/services/notification_service_port.dart';
import 'finance_repository.dart';
import 'forecast_service.dart';
import 'goal_repository.dart';
import 'local_assistant.dart';
import 'goal_planning_service.dart';
import 'planned_expense_repository.dart';
import 'smart_planner.dart';
import 'task_repository.dart';
import 'voice_nlu.dart';

/// پردازشگر فرمان صوتی فارسی
///
/// **اصلاحات 2026-08-07:**
/// - تمام repositoryها حالا required و non-nullable هستند (قبلاً nullable بودند و
///   پیام «هنوز به فرمان صوتی وصل نشده است» برمی‌گرداندند). حالا تضمین شده همه
///   repoها در دسترس هستند.
/// - حذف استفاده از `!` و fallback های ناامن.
/// - پیام‌های کاربرمحورتر به جای پیام فنی «وصل نشده».
class VoiceCommandProcessor {
  VoiceCommandProcessor({
    required this.taskRepository,
    required this.financeRepository,
    required this.goalRepository,
    required this.plannedExpenseRepository,
    required this.debtRepository,
    required this.allocationRepository,
    this.conversationMemory,
    ForecastService forecastService = const ForecastService(),
    CommandConfidenceService confidenceService = const CommandConfidenceService(),
    this.notificationService,
    SmartPlanner planner = const SmartPlanner(),
    FinanceAssistant financeAssistant = const FinanceAssistant(),
  })  : _planner = planner,
        _financeAssistant = financeAssistant,
        _forecastService = forecastService,
        _confidenceService = confidenceService {
    _assistant = RuleBasedLocalAssistant(planner: planner);
  }

  final TaskRepository taskRepository;
  final FinanceRepository financeRepository;
  final GoalRepository goalRepository;
  final PlannedExpenseRepository plannedExpenseRepository;
  final DebtRepository debtRepository;
  final AllocationRepository allocationRepository;
  final ConversationMemoryService? conversationMemory;
  final NotificationServicePort? notificationService;
  final SmartPlanner _planner;
  final ForecastService _forecastService;
  final CommandConfidenceService _confidenceService;
  final FinanceAssistant _financeAssistant;
  late final RuleBasedLocalAssistant _assistant;

  Future<String> handle(String rawText) async {
    final text = VoiceNlu.normalize(rawText);
    if (text.isEmpty) return 'چیزی تشخیص داده نشد. دوباره دکمه میکروفون را نگه دار و واضح‌تر بگو.';

    if (conversationMemory?.hasPending == true) {
      return _continuePendingConversation(rawText, text);
    }

    if (VoiceNlu.containsAny(text, ['اگه فردا کار نکنم', 'اگر فردا کار نکنم', 'فردا کار نکنم چی میشه'])) {
      return _forecastService.noWorkTomorrowImpact(
        debts: debtRepository,
        plannedExpenses: plannedExpenseRepository,
        allocations: allocationRepository,
      );
    }

    if (VoiceNlu.containsAny(text, ['اگه امروز', 'اگر امروز']) && VoiceNlu.containsAny(text, ['ساعت کار کنم', 'ساعت کار'])) {
      final hours = _extractWorkHours(text) ?? 1;
      return _forecastService.workHoursImpact(
        hours: hours,
        finance: financeRepository,
        debts: debtRepository,
        plannedExpenses: plannedExpenseRepository,
        allocations: allocationRepository,
      );
    }

    if (VoiceNlu.containsAny(text, ['ریسک', 'خطر', 'عقب میفتم', 'عقب می‌افتم'])) {
      return _forecastService.riskSummary(
        debts: debtRepository,
        plannedExpenses: plannedExpenseRepository,
        allocations: allocationRepository,
      );
    }

    if (_isIncompleteDebt(text)) {
      return _startIncompleteDebtConversation(text);
    }

    if (VoiceNlu.containsAny(text, ['کنار بگذار', 'کنار بذار', 'اختصاص بده', 'بذار برای'])) {
      return _handleAllocationCommand(text);
    }

    if (VoiceNlu.containsAny(text, ['بدهی']) && VoiceNlu.containsAny(text, ['پرداخت کردم', 'پس دادم', 'تسویه کردم'])) {
      return _handleDebtPaymentCommand(text);
    }

    if (VoiceNlu.containsAny(text, ['بدهکارم', 'بدهکار هستم', 'بدهی دارم', 'طلب دارم', 'ازم طلب داره', 'ازش طلب دارم'])) {
      final multiNames = VoiceNlu.extractMultiDebtPersons(text);
      if (multiNames.length >= 2) {
        return _handleMultiDebtCommand(rawText, text, multiNames);
      }
      return _handleDebtCommand(rawText, text);
    }

    if (VoiceNlu.containsAny(text, ['خرج داره', 'هزینه داره', 'میخام برم', 'میخوام برم', 'می‌خوام برم', 'برنامه هزینه'])) {
      return _handlePlannedExpenseCommand(rawText, text);
    }

    if (VoiceNlu.containsAny(text, ['هدف درآمد', 'هدف روزانه', 'هدف ماهانه'])) {
      return _handleGoalCommand(text);
    }

    if (VoiceNlu.containsAny(text, ['چقدر باید کار کنم', 'چقدر کار کنم', 'چقدر مونده', 'چقدر مانده'])) {
      return _incomeGapAnswer();
    }

    if (VoiceNlu.containsAny(text, ['کامل شد', 'تمام شد', 'انجام شد', 'تموم شد'])) {
      return _completeTaskByVoice(text);
    }

    if (VoiceNlu.containsAny(text, ['درآمد', 'دریافتی', 'پول گرفتم', 'واریز'])) {
      final amount = VoiceNlu.parseAmount(text);
      if (amount <= 0) {
        return 'متوجه شدم می‌خوای درآمد ثبت کنی، ولی مبلغ را نفهمیدم. مثلاً بگو: درآمد سه میلیون تومان ثبت کن.';
      }
      final transaction = FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: FinanceTransactionType.income,
        amount: amount,
        createdAt: DateTime.now(),
        note: rawText.trim(),
        category: 'ثبت صوتی',
      );
      await financeRepository.add(transaction);
      return 'درآمد ${PersianFormat.money(amount)} ثبت شد و به درآمد فعلی اضافه شد.';
    }

    if (VoiceNlu.containsAny(text, ['هزینه', 'خرج', 'پرداخت کردم', 'خریدم'])) {
      final amount = VoiceNlu.parseAmount(text);
      if (amount <= 0) {
        return 'متوجه شدم می‌خوای هزینه ثبت کنی، ولی مبلغ را نفهمیدم. مثلاً بگو: هزینه دویست هزار تومان ثبت کن.';
      }
      final confidence = _confidenceService.evaluate(text: text, intent: 'expense', amount: amount);
      if (_confidenceService.shouldConfirm(confidence, amount: amount)) {
        await conversationMemory?.setPending('confirm_sensitive', {
          'action': 'expense',
          'amount': amount,
          'category': 'ثبت صوتی',
          'rawText': rawText.trim(),
        });
        return 'برای اطمینان، هزینه ${PersianFormat.money(amount)} ثبت شود؟ بگو «تأیید» یا «لغو». اطمینان من: ${PersianFormat.digits((confidence.score * 100).round())}٪.';
      }
      final transaction = FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: FinanceTransactionType.expense,
        amount: amount,
        createdAt: DateTime.now(),
        note: rawText.trim(),
        category: 'ثبت صوتی',
      );
      await financeRepository.add(transaction);
      return 'هزینه ${PersianFormat.money(amount)} ثبت شد.';
    }

    if (VoiceNlu.containsAny(text, ['کار جدید', 'وظیفه جدید', 'اضافه کن', 'ثبت کن', 'یادم بنداز'])) {
      return _addTaskByVoice(rawText, text);
    }

    if (VoiceNlu.containsAny(text, ['برنامه امروز', 'امروزمو بچین', 'زمان بندی', 'زمان‌بندی'])) {
      return _assistant.generate(prompt: 'برنامه امروزمو بچین', tasks: taskRepository.tasks);
    }

    if (VoiceNlu.containsAny(text, ['الان چی کار کنم', 'کار بعدی', 'اول چی', 'اولویت'])) {
      return _assistant.generate(prompt: 'الان چی کار کنم', tasks: taskRepository.tasks);
    }

    if (VoiceNlu.containsAny(text, ['وضع مالی', 'حسابم', 'درآمد امروز', 'درآمد ماه'])) {
      final incomeToday = financeRepository.incomeToday();
      final incomeMonth = financeRepository.incomeThisMonth();
      final netMonth = financeRepository.netThisMonth();
      return 'درآمد امروز ${PersianFormat.money(incomeToday)}، درآمد این ماه ${PersianFormat.money(incomeMonth)} و خالص این ماه ${PersianFormat.money(netMonth)} است.';
    }

    return _assistant.generate(prompt: rawText, tasks: taskRepository.tasks);
  }

  Future<String> _continuePendingConversation(String rawText, String text) async {
    final memory = conversationMemory;
    final pending = memory?.pending;
    if (memory == null || pending == null) return 'گفت‌وگوی نیمه‌کاره‌ای پیدا نکردم.';

    if (pending.type == 'confirm_allocation') {
      if (VoiceNlu.containsAny(text, ['آره', 'بله', 'درسته', 'تایید', 'تأیید', 'اوکی'])) {
        final slots = pending.slots;
        await allocationRepository.add(MoneyAllocation(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          targetType: AllocationTargetType.values.firstWhere(
            (t) => t.name == slots['targetType'],
            orElse: () => AllocationTargetType.free,
          ),
          targetId: slots['targetId'] as String? ?? '',
          amount: slots['amount'] as int? ?? 0,
          createdAt: DateTime.now(),
          note: slots['note'] as String? ?? 'ثبت با تأیید کاربر',
        ));
        await memory.clearPending();
        return '${PersianFormat.money(slots['amount'] as int? ?? 0)} کنار گذاشته شد.';
      }
      await memory.clearPending();
      return 'باشه، انجام ندادم. لطفاً فرمان را دقیق‌تر بگو.';
    }

    if (pending.type == 'confirm_sensitive') {
      if (_isAffirmative(text)) {
        final result = await _executeConfirmedSensitiveAction(pending.slots);
        await memory.clearPending();
        return result;
      }
      if (_isNegative(text)) {
        await memory.clearPending();
        return 'باشه، عملیات مالی انجام نشد.';
      }
      return 'برای انجام این عملیات مالی بگو «تأیید»، یا اگر نمی‌خواهی بگو «لغو».';
    }

    if (pending.type == 'debt') {
      final slots = Map<String, dynamic>.from(pending.slots);
      slots['amount'] ??= VoiceNlu.parseAmount(text);
      if ((slots['amount'] as int? ?? 0) <= 0) {
        await memory.updatePending(slots);
        return 'مبلغ را نفهمیدم. مثلاً بگو: یک میلیون تومان.';
      }

      final due = VoiceNlu.guessDueAt(text);
      if (due != null) slots['dueAt'] = due.toIso8601String();
      if (slots['dueAt'] == null) {
        await memory.updatePending(slots);
        return 'تا کی باید پس بدی؟ مثلاً بگو: تا دو روز دیگه.';
      }

      final item = DebtItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: DebtType.debt,
        personName: slots['personName'] as String? ?? 'نامشخص',
        amount: slots['amount'] as int,
        dueAt: DateTime.parse(slots['dueAt'] as String),
        createdAt: DateTime.now(),
        notes: 'ثبت‌شده با گفت‌وگوی چندمرحله‌ای: $rawText',
      );
      await debtRepository.add(item);
      await memory.clearPending();
      await memory.rememberEntity(type: 'debt', id: item.id, title: item.personName);
      final status = const DebtPlanningService().statusFor(item, financeRepository);
      return 'ثبت شد. ${status.message}';
    }

    await memory.clearPending();
    return 'گفت‌وگوی قبلی را متوجه نشدم؛ لطفاً دوباره کامل بگو.';
  }

  Future<String> _startIncompleteDebtConversation(String text) async {
    final person = VoiceNlu.extractPersonNameForDebt(text, DebtType.debt);
    await conversationMemory?.setPending('debt', {
      'personName': person.isEmpty ? 'نامشخص' : person,
    });
    return 'باشه، بدهی ${person.isEmpty ? '' : person} را ثبت می‌کنم. چقدر بدهکاری؟';
  }

  bool _isIncompleteDebt(String text) {
    return VoiceNlu.containsAny(text, ['بدهکارم', 'بدهی دارم']) && VoiceNlu.parseAmount(text) <= 0;
  }

  double? _extractWorkHours(String text) {
    final normalized = VoiceNlu.convertPersianDigits(text);
    final digitMatch = RegExp(r'(\d+(\.\d+)?)\s*ساعت').firstMatch(normalized);
    if (digitMatch != null) return double.tryParse(digitMatch.group(1)!);

    final wordMatch = RegExp(r'(یک|یه|دو|سه|چهار|پنج|شش|شیش|هفت|هشت|نه|ده)\s*ساعت').firstMatch(normalized);
    if (wordMatch != null) return (VoiceNlu.parseSmallNumber(wordMatch.group(1)!) ?? 1).toDouble();
    return null;
  }

  Future<String> _executeConfirmedSensitiveAction(Map<String, dynamic> slots) async {
    final action = slots['action'] as String? ?? '';

    if (action == 'debt') {
      final type = DebtType.values.firstWhere(
        (t) => t.name == slots['debtType'],
        orElse: () => DebtType.debt,
      );
      final item = DebtItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        personName: slots['personName'] as String? ?? 'نامشخص',
        amount: slots['amount'] as int? ?? 0,
        dueAt: DateTime.parse(slots['dueAt'] as String),
        createdAt: DateTime.now(),
        notes: slots['rawText'] as String? ?? '',
      );
      await debtRepository.add(item);
      await conversationMemory?.rememberEntity(type: 'debt', id: item.id, title: item.personName);
      final status = const DebtPlanningService().statusFor(item, financeRepository);
      return 'ثبت شد. ${status.message}';
    }

    if (action == 'plannedExpense') {
      final item = PlannedExpenseGoal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: slots['title'] as String? ?? 'هزینه برنامه‌ریزی‌شده',
        targetAmount: slots['amount'] as int? ?? 0,
        dueAt: DateTime.parse(slots['dueAt'] as String),
        createdAt: DateTime.now(),
        notes: slots['rawText'] as String? ?? '',
      );
      await plannedExpenseRepository.add(item);
      final status = const GoalPlanningService().statusFor(item, financeRepository);
      return 'ثبت شد. ${status.message}';
    }

    if (action == 'expense') {
      final amount = slots['amount'] as int? ?? 0;
      await financeRepository.add(FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: FinanceTransactionType.expense,
        amount: amount,
        createdAt: DateTime.now(),
        note: slots['rawText'] as String? ?? '',
        category: slots['category'] as String? ?? 'ثبت صوتی',
      ));
      return 'هزینه ${PersianFormat.money(amount)} ثبت شد.';
    }

    return 'نوع عملیات تأییدشده را نشناختم.';
  }

  bool _isAffirmative(String text) => VoiceNlu.containsAny(text, ['تأیید', 'تایید', 'بله', 'آره', 'درسته', 'اوکی', 'انجام بده']);
  bool _isNegative(String text) => VoiceNlu.containsAny(text, ['لغو', 'نه', 'نکن', 'بیخیال', 'اشتباهه']);

  Future<String> _handleAllocationCommand(String text) async {
    var amount = VoiceNlu.parseAmount(text);
    final ambiguousAmount = VoiceNlu.parseAmbiguousSpokenAmount(text);
    if (amount <= 0 && ambiguousAmount != null) {
      amount = ambiguousAmount;
    }
    if (amount <= 0) return 'مبلغی که باید کنار گذاشته شود را نفهمیدم.';

    if (VoiceNlu.containsAny(text, ['براش', 'برای اون', 'همون', 'قبلی'])) {
      final entity = conversationMemory?.lastEntity ?? {};
      if (entity['type'] == 'debt') {
        await conversationMemory?.setPending('confirm_allocation', {
          'targetType': AllocationTargetType.debt.name,
          'targetId': entity['id'],
          'amount': amount,
          'note': 'کنار گذاشته‌شده برای ${entity['title']}',
        });
        return 'منظورت اینه ${PersianFormat.money(amount)} برای بدهی ${entity['title']} کنار بگذارم؟ اگر درسته بگو «تأیید».'.replaceAll('null', 'قبلی');
      }
    }

    if (VoiceNlu.containsAny(text, ['بدهی'])) {
      final debts = debtRepository.activeItems.where((e) => e.type == DebtType.debt).toList();
      if (debts.isEmpty) return 'بدهی فعالی پیدا نکردم. اول بگو: به فلانی اینقدر بدهکارم.';
      DebtItem? target;
      for (final debt in debts) {
        if (text.contains(debt.personName)) {
          target = debt;
          break;
        }
      }
      target ??= debts.first;
      await allocationRepository.add(MoneyAllocation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        targetType: AllocationTargetType.debt,
        targetId: target.id,
        amount: amount,
        createdAt: DateTime.now(),
        note: 'کنار گذاشته‌شده برای بدهی ${target.personName}',
      ));
      return '${PersianFormat.money(amount)} برای بدهی ${target.personName} کنار گذاشته شد.';
    }

    final plans = plannedExpenseRepository.activeItems;
    if (plans.isEmpty) return 'هزینه آینده فعالی پیدا نکردم. اول هزینه آینده‌ات رو ثبت کن.';
    final target = plans.first;
    await allocationRepository.add(MoneyAllocation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      targetType: AllocationTargetType.plannedExpense,
      targetId: target.id,
      amount: amount,
      createdAt: DateTime.now(),
      note: 'کنار گذاشته‌شده برای ${target.title}',
    ));
    return '${PersianFormat.money(amount)} برای «${target.title}» کنار گذاشته شد.';
  }

  Future<String> _handleDebtPaymentCommand(String text) async {
    final activeDebts = debtRepository.activeItems.where((e) => e.type == DebtType.debt).toList();
    if (activeDebts.isEmpty) return 'بدهی فعالی برای پرداخت پیدا نکردم.';

    DebtItem? best;
    for (final item in activeDebts) {
      if (text.contains(item.personName)) {
        best = item;
        break;
      }
    }
    best ??= activeDebts.first;

    final amount = VoiceNlu.parseAmount(text);
    final payment = amount > 0 ? amount : best.remainingAmount;
    await debtRepository.addPayment(best.id, payment);
    await financeRepository.add(
      FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: FinanceTransactionType.expense,
        amount: payment,
        createdAt: DateTime.now(),
        note: 'پرداخت بدهی به ${best.personName}',
        category: 'بدهی',
      ),
    );

    return 'پرداخت ${PersianFormat.money(payment)} برای بدهی ${best.personName} ثبت شد.';
  }

  /// ثبت دسته‌ای چند بدهی + محاسبهٔ فوری برنامهٔ پرداخت.
  Future<String> _handleMultiDebtCommand(
      String rawText, String text, List<String> persons) async {
    final dueAt = VoiceNlu.guessDueAt(text) ?? DateTime.now().add(const Duration(days: 30));
    final type = VoiceNlu.containsAny(text, ['طلب دارم', 'ازش طلب دارم'])
        ? DebtType.receivable
        : DebtType.debt;

    final registered = <String, int>{};
    for (final person in persons) {
      final amount = VoiceNlu.extractAmountForPerson(text, person);
      if (amount == null || amount <= 0) continue;

      final item = DebtItem(
        id: DateTime.now().microsecondsSinceEpoch.toString() + person,
        type: type,
        personName: person,
        amount: amount,
        dueAt: dueAt,
        createdAt: DateTime.now(),
        notes: rawText.trim(),
      );
      await debtRepository.add(item);
      registered[person] = amount;
    }

    if (registered.isEmpty) {
      return 'چند نفر را شنیدم ولی مبلغ‌ها را کامل نفهمیدم. مثال: «به علی و محمد بدهکارم، به علی ۲۰ میلیون، به محمد پنج میلیون، تا ماه آینده».';
    }

    final total = registered.values.fold<int>(0, (a, b) => a + b);
    final now = DateTime.now();
    final horizonDays = DateTime(dueAt.year, dueAt.month, dueAt.day)
                .difference(DateTime(now.year, now.month, now.day))
                .inDays >
            0
        ? DateTime(dueAt.year, dueAt.month, dueAt.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays
        : 1;
    final requiredDaily = (total / horizonDays).ceil();
    final hourly = financeRepository.averageHourlyRate();
    final requiredHours = hourly > 0 ? requiredDaily / hourly : 0.0;

    final buffer = StringBuffer()
      ..writeln('${PersianFormat.digits(registered.length)} بدهی ثبت شد:')
      ..writeln(registered.entries
          .map((e) => '• ${e.key}: ${PersianFormat.money(e.value)}')
          .join('\n'))
      ..writeln('مجموع: ${PersianFormat.money(total)}، مهلت: ${PersianFormat.jalaliDate(dueAt)} (${PersianFormat.digits(horizonDays)} روز).')
      ..writeln('برای پرداخت همه باید روزی حدود ${PersianFormat.money(requiredDaily)} در بیاوری.');
    if (hourly > 0) {
      buffer.writeln('با میانگین درآمد ساعتی ${PersianFormat.money(hourly.round())}، یعنی ${PersianFormat.digits(requiredHours.toStringAsFixed(requiredHours >= 10 ? 0 : 1))} ساعت کار در روز.');
    } else {
      buffer.writeln('برای محاسبهٔ ساعت دقیق، چند کار درآمدزا با زمان واقعی ثبت کن.');
    }
    buffer.writeln('اولویت با فوری‌ترین مهلت است؛ برای برنامهٔ کامل بگو «برنامه پرداخت بدهی‌ها».');
    return buffer.toString();
  }

  Future<String> _handleDebtCommand(String rawText, String text) async {
    final amount = VoiceNlu.parseAmount(text);
    if (amount <= 0) {
      return 'مبلغ بدهی یا طلب را نفهمیدم. مثلاً بگو: به ممد یک میلیون بدهکارم تا دو روز دیگه باید پس بدم.';
    }

    final type = VoiceNlu.containsAny(text, ['طلب دارم', 'ازش طلب دارم']) ? DebtType.receivable : DebtType.debt;
    final person = VoiceNlu.extractPersonNameForDebt(text, type);
    final dueAt = VoiceNlu.guessDueAt(text) ?? DateTime.now().add(const Duration(days: 2));
    final confidence = _confidenceService.evaluate(
      text: text,
      intent: 'debt',
      amount: amount,
      personName: person,
      dueAt: dueAt,
    );
    if (_confidenceService.shouldConfirm(confidence, amount: amount)) {
      await conversationMemory?.setPending('confirm_sensitive', {
        'action': 'debt',
        'debtType': type.name,
        'personName': person.isEmpty ? 'نامشخص' : person,
        'amount': amount,
        'dueAt': dueAt.toIso8601String(),
        'rawText': rawText.trim(),
      });
      return 'برای اطمینان، ${type.faLabel} ${person.isEmpty ? 'نامشخص' : person} به مبلغ ${PersianFormat.money(amount)} با مهلت ${PersianFormat.jalaliLong(dueAt)} ثبت شود؟ بگو «تأیید» یا «لغو». اطمینان من: ${PersianFormat.digits((confidence.score * 100).round())}٪.';
    }

    final item = DebtItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      personName: person.isEmpty ? 'نامشخص' : person,
      amount: amount,
      dueAt: dueAt,
      createdAt: DateTime.now(),
      notes: rawText.trim(),
    );
    await debtRepository.add(item);
    await conversationMemory?.rememberEntity(type: 'debt', id: item.id, title: item.personName);

    final status = const DebtPlanningService().statusFor(item, financeRepository);
    return '${type.faLabel} ${item.personName} به مبلغ ${PersianFormat.money(amount)} با مهلت ${PersianFormat.jalaliLong(dueAt)} ثبت شد. ${status.message} اگر یک روز کمتر درآمد داشته باشی، محاسبه روزهای بعدی با باقی‌مانده جدید خودکار به‌روز می‌شود.';
  }

  Future<String> _handlePlannedExpenseCommand(String rawText, String text) async {
    final amount = VoiceNlu.parseAmount(text);
    if (amount <= 0) {
      return 'مبلغ هزینه را نفهمیدم. مثلاً بگو: هفته دیگه می‌خوام برم بیرون و یک میلیون تومان خرج داره.';
    }

    final dueAt = VoiceNlu.guessDueAt(text) ?? DateTime.now().add(const Duration(days: 7));
    final title = VoiceNlu.cleanPlannedExpenseTitle(rawText);
    final confidence = _confidenceService.evaluate(
      text: text,
      intent: 'plannedExpense',
      amount: amount,
      dueAt: dueAt,
    );
    if (_confidenceService.shouldConfirm(confidence, amount: amount)) {
      await conversationMemory?.setPending('confirm_sensitive', {
        'action': 'plannedExpense',
        'title': title.isEmpty ? 'هزینه برنامه‌ریزی‌شده' : title,
        'amount': amount,
        'dueAt': dueAt.toIso8601String(),
        'rawText': rawText.trim(),
      });
      return 'برای اطمینان، هزینه آینده «${title.isEmpty ? 'هزینه برنامه‌ریزی‌شده' : title}» با مبلغ ${PersianFormat.money(amount)} برای ${PersianFormat.jalaliLong(dueAt)} ثبت شود؟ بگو «تأیید» یا «لغو». اطمینان من: ${PersianFormat.digits((confidence.score * 100).round())}٪.';
    }

    final item = PlannedExpenseGoal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'هزینه برنامه‌ریزی‌شده' : title,
      targetAmount: amount,
      dueAt: dueAt,
      createdAt: DateTime.now(),
      notes: rawText.trim(),
    );
    await plannedExpenseRepository.add(item);

    final status = const GoalPlanningService().statusFor(item, financeRepository);
    return 'برنامه هزینه «${item.title}» با مبلغ ${PersianFormat.money(amount)} برای ${PersianFormat.jalaliLong(dueAt)} ثبت شد. ${status.message} اگر یک روز کمتر درآمد داشته باشی، روزهای بعدی خودکار با باقی‌مانده جدید محاسبه می‌شود.';
  }

  Future<String> _handleGoalCommand(String text) async {
    final amount = VoiceNlu.parseAmount(text);
    if (amount <= 0) {
      return 'مبلغ هدف را نفهمیدم. مثلاً بگو: هدف درآمد روزانه یک میلیون تومان.';
    }

    if (VoiceNlu.containsAny(text, ['ماهانه', 'ماه شمسی', 'این ماه'])) {
      await goalRepository.setMonthlyIncomeGoal(amount);
      return 'هدف درآمد ماه شمسی روی ${PersianFormat.money(amount)} تنظیم شد.';
    }

    await goalRepository.setDailyIncomeGoal(amount);
    return 'هدف درآمد روزانه روی ${PersianFormat.money(amount)} تنظیم شد.';
  }

  String _incomeGapAnswer() {
    if (goalRepository.dailyIncomeGoal <= 0) {
      return 'برای محاسبه زمان لازم، اول هدف درآمد روزانه را تنظیم کن. مثلاً بگو: هدف درآمد روزانه یک میلیون تومان.';
    }

    final gap = goalRepository.dailyIncomeGoal - financeRepository.incomeToday();
    if (gap <= 0) return 'هدف درآمد امروزت کامل شده است.';

    final hourly = financeRepository.averageHourlyRate();
    if (hourly <= 0) {
      return 'هنوز میانگین درآمد ساعتی ندارم. چند کار درآمدزا را با زمان واقعی و مبلغ درآمد ثبت کن تا دقیق حساب کنم.';
    }

    final minutes = (gap / hourly * 60).ceil();
    return 'برای رسیدن به هدف امروز، حدود ${PersianFormat.money(gap)} دیگر نیاز داری؛ با میانگین فعلی یعنی حدود ${PersianFormat.minutes(minutes)} کار درآمدزا.';
  }

  Future<String> _addTaskByVoice(String rawText, String normalized) async {
    final dueAt = VoiceNlu.guessDueAt(normalized);
    final title = VoiceNlu.cleanTaskTitle(rawText);

    if (title.isEmpty || title.length < 3) {
      return 'عنوان کار را نفهمیدم. مثلاً بگو: کار جدید تماس با مشتری اضافه کن.';
    }

    final now = DateTime.now();
    final task = Task(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      category: VoiceNlu.looksLikeWork(normalized) ? 'کار' : 'ثبت صوتی',
      createdAt: now,
      dueAt: dueAt,
      importance: VoiceNlu.containsAny(normalized, ['خیلی مهم', 'فوری', 'ضروری']) ? 5 : 3,
      energy: VoiceNlu.containsAny(normalized, ['سخت', 'تمرکز', 'سنگین']) ? EnergyLevel.high : EnergyLevel.medium,
      estimatedMinutes: VoiceNlu.guessMinutes(normalized),
      isPinned: VoiceNlu.containsAny(normalized, ['فوری', 'خیلی مهم']),
    );

    await taskRepository.add(task);
    await notificationService?.scheduleTaskReminder(task);
    return 'کار «${task.title}» اضافه شد. زمان تخمینی ${PersianFormat.minutes(task.estimatedMinutes)} است${task.dueAt == null ? '' : ' و یادآوری مهلت انجام هم تنظیم شد'}.';
  }

  Future<String> _completeTaskByVoice(String text) async {
    final openTasks = taskRepository.tasks.where((t) => !t.isDone).toList();
    if (openTasks.isEmpty) return 'کاری برای کامل کردن پیدا نکردم.';

    Task? best;
    var bestScore = 0;
    for (final task in openTasks) {
      final score = VoiceNlu.wordOverlap(VoiceNlu.normalize(task.title), text);
      if (score > bestScore) {
        bestScore = score;
        best = task;
      }
    }

    best ??= (openTasks..sort((a, b) => _planner.priorityScore(b).compareTo(_planner.priorityScore(a)))).first;
    final minutes = VoiceNlu.guessMinutes(text, fallback: best.estimatedMinutes);
    await taskRepository.complete(best.id, actualMinutes: minutes);
    await notificationService?.cancelTaskReminder(best.id);

    final amount = VoiceNlu.parseAmount(text);
    if (amount > 0 || _financeAssistant.isWorkTask(best)) {
      if (amount > 0) {
        await financeRepository.add(
          FinanceTransaction(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: FinanceTransactionType.income,
            amount: amount,
            createdAt: DateTime.now(),
            note: 'درآمد ثبت‌شده با فرمان صوتی برای ${best.title}',
            category: best.category,
            taskId: best.id,
            minutesWorked: minutes,
          ),
        );
        return 'کار «${best.title}» کامل شد و درآمد ${PersianFormat.money(amount)} هم ثبت شد.';
      }
      return 'کار «${best.title}» کامل شد. چون این کار احتمالاً درآمدی است، از تب حسابدار می‌توانی درآمدش را ثبت کنی یا بگویی: درآمد سه میلیون ثبت کن.';
    }

    return 'کار «${best.title}» کامل شد.';
  }
}
