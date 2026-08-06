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

class VoiceCommandProcessor {
  VoiceCommandProcessor({
    required this.taskRepository,
    required this.financeRepository,
    this.goalRepository,
    this.plannedExpenseRepository,
    this.debtRepository,
    this.allocationRepository,
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
  final GoalRepository? goalRepository;
  final PlannedExpenseRepository? plannedExpenseRepository;
  final DebtRepository? debtRepository;
  final AllocationRepository? allocationRepository;
  final ConversationMemoryService? conversationMemory;
  final NotificationServicePort? notificationService;
  final SmartPlanner _planner;
  final ForecastService _forecastService;
  final CommandConfidenceService _confidenceService;
  final FinanceAssistant _financeAssistant;
  late final RuleBasedLocalAssistant _assistant;

  Future<String> handle(String rawText) async {
    final text = _normalize(rawText);
    if (text.isEmpty) return 'چیزی تشخیص داده نشد. دوباره دکمه میکروفون را نگه دار و واضح‌تر بگو.';

    if (conversationMemory?.hasPending == true) {
      return _continuePendingConversation(rawText, text);
    }

    if (_containsAny(text, ['اگه فردا کار نکنم', 'اگر فردا کار نکنم', 'فردا کار نکنم چی میشه'])) {
      return _forecastService.noWorkTomorrowImpact(
        debts: debtRepository!,
        plannedExpenses: plannedExpenseRepository!,
        allocations: allocationRepository!,
      );
    }

    if (_containsAny(text, ['اگه امروز', 'اگر امروز']) && _containsAny(text, ['ساعت کار کنم', 'ساعت کار'])) {
      final hours = _extractWorkHours(text) ?? 1;
      return _forecastService.workHoursImpact(
        hours: hours,
        finance: financeRepository,
        debts: debtRepository!,
        plannedExpenses: plannedExpenseRepository!,
        allocations: allocationRepository!,
      );
    }

    if (_containsAny(text, ['ریسک', 'خطر', 'عقب میفتم', 'عقب می‌افتم'])) {
      return _forecastService.riskSummary(
        debts: debtRepository!,
        plannedExpenses: plannedExpenseRepository!,
        allocations: allocationRepository!,
      );
    }

    if (_isIncompleteDebt(text)) {
      return _startIncompleteDebtConversation(text);
    }

    if (_containsAny(text, ['کنار بگذار', 'کنار بذار', 'اختصاص بده', 'بذار برای'])) {
      return _handleAllocationCommand(text);
    }

    if (_containsAny(text, ['بدهی']) && _containsAny(text, ['پرداخت کردم', 'پس دادم', 'تسویه کردم'])) {
      return _handleDebtPaymentCommand(text);
    }

    if (_containsAny(text, ['بدهکارم', 'بدهکار هستم', 'بدهی دارم', 'طلب دارم', 'ازم طلب داره', 'ازش طلب دارم'])) {
      // اگر چند نفر با مبالغ جدا در یک جمله باشند («به علی و محمد بدهکارم،
      // به علی ۲۰ میل...») → ثبت دسته‌ای + محاسبهٔ برنامهٔ پرداخت
      final multiNames = _extractMultiDebtPersons(text);
      if (multiNames.length >= 2) {
        return _handleMultiDebtCommand(rawText, text, multiNames);
      }
      return _handleDebtCommand(rawText, text);
    }

    if (_containsAny(text, ['خرج داره', 'هزینه داره', 'میخام برم', 'میخوام برم', 'می‌خوام برم', 'برنامه هزینه'])) {
      return _handlePlannedExpenseCommand(rawText, text);
    }

    if (_containsAny(text, ['هدف درآمد', 'هدف روزانه', 'هدف ماهانه'])) {
      return _handleGoalCommand(text);
    }

    if (_containsAny(text, ['چقدر باید کار کنم', 'چقدر کار کنم', 'چقدر مونده', 'چقدر مانده'])) {
      return _incomeGapAnswer();
    }

    if (_containsAny(text, ['کامل شد', 'تمام شد', 'انجام شد', 'تموم شد'])) {
      return _completeTaskByVoice(text);
    }

    if (_containsAny(text, ['درآمد', 'دریافتی', 'پول گرفتم', 'واریز'])) {
      final amount = _parseAmount(text);
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

    if (_containsAny(text, ['هزینه', 'خرج', 'پرداخت کردم', 'خریدم'])) {
      final amount = _parseAmount(text);
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

    if (_containsAny(text, ['کار جدید', 'کار جدید', 'وظیفه جدید', 'اضافه کن', 'ثبت کن', 'یادم بنداز'])) {
      return _addTaskByVoice(rawText, text);
    }

    if (_containsAny(text, ['برنامه امروز', 'امروزمو بچین', 'زمان بندی', 'زمان‌بندی'])) {
      return _assistant.generate(prompt: 'برنامه امروزمو بچین', tasks: taskRepository.tasks);
    }

    if (_containsAny(text, ['الان چی کار کنم', 'کار بعدی', 'اول چی', 'اولویت'])) {
      return _assistant.generate(prompt: 'الان چی کار کنم', tasks: taskRepository.tasks);
    }

    if (_containsAny(text, ['وضع مالی', 'حسابم', 'درآمد امروز', 'درآمد ماه'])) {
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
      if (_containsAny(text, ['آره', 'بله', 'درسته', 'تایید', 'تأیید', 'اوکی'])) {
        final slots = pending.slots;
        final allocations = allocationRepository;
        if (allocations == null) return 'بخش پاکت پول در دسترس نیست.';
        await allocations.add(MoneyAllocation(
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
      slots['amount'] ??= _parseAmount(text);
      if ((slots['amount'] as int? ?? 0) <= 0) {
        await memory.updatePending(slots);
        return 'مبلغ را نفهمیدم. مثلاً بگو: یک میلیون تومان.';
      }

      final due = _guessDueAt(text);
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
      await debtRepository?.add(item);
      await memory.clearPending();
      await memory.rememberEntity(type: 'debt', id: item.id, title: item.personName);
      final status = const DebtPlanningService().statusFor(item, financeRepository);
      return 'ثبت شد. ${status.message}';
    }

    await memory.clearPending();
    return 'گفت‌وگوی قبلی را متوجه نشدم؛ لطفاً دوباره کامل بگو.';
  }

  Future<String> _startIncompleteDebtConversation(String text) async {
    final person = _extractPersonNameForDebt(text, DebtType.debt);
    await conversationMemory?.setPending('debt', {
      'personName': person.isEmpty ? 'نامشخص' : person,
    });
    return 'باشه، بدهی ${person.isEmpty ? '' : person} را ثبت می‌کنم. چقدر بدهکاری؟';
  }

  bool _isIncompleteDebt(String text) {
    return _containsAny(text, ['بدهکارم', 'بدهی دارم']) && _parseAmount(text) <= 0;
  }

  double? _extractWorkHours(String text) {
    final normalized = _convertPersianDigits(text);
    final digitMatch = RegExp(r'(\d+(\.\d+)?)\s*ساعت').firstMatch(normalized);
    if (digitMatch != null) return double.tryParse(digitMatch.group(1)!);

    final wordMatch = RegExp(r'(یک|یه|دو|سه|چهار|پنج|شش|شیش|هفت|هشت|نه|ده)\s*ساعت').firstMatch(normalized);
    if (wordMatch != null) return (_parseSmallNumber(wordMatch.group(1)!) ?? 1).toDouble();
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
      await debtRepository?.add(item);
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
      await plannedExpenseRepository?.add(item);
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

  bool _isAffirmative(String text) => _containsAny(text, ['تأیید', 'تایید', 'بله', 'آره', 'درسته', 'اوکی', 'انجام بده']);
  bool _isNegative(String text) => _containsAny(text, ['لغو', 'نه', 'نکن', 'بیخیال', 'اشتباهه']);

  Future<String> _handleAllocationCommand(String text) async {
    final allocations = allocationRepository;
    if (allocations == null) return 'بخش پاکت پول هنوز به فرمان صوتی وصل نشده است.';

    var amount = _parseAmount(text);
    final ambiguousAmount = _parseAmbiguousSpokenAmount(text);
    if (amount <= 0 && ambiguousAmount != null) {
      amount = ambiguousAmount;
    }
    if (amount <= 0) return 'مبلغی که باید کنار گذاشته شود را نفهمیدم.';

    if (_containsAny(text, ['براش', 'برای اون', 'همون', 'قبلی'])) {
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

    if (_containsAny(text, ['بدهی'])) {
      final debts = debtRepository?.activeItems.where((e) => e.type == DebtType.debt).toList() ?? [];
      if (debts.isEmpty) return 'بدهی فعالی پیدا نکردم.';
      DebtItem? target;
      for (final debt in debts) {
        if (text.contains(debt.personName)) {
          target = debt;
          break;
        }
      }
      target ??= debts.first;
      await allocations.add(MoneyAllocation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        targetType: AllocationTargetType.debt,
        targetId: target.id,
        amount: amount,
        createdAt: DateTime.now(),
        note: 'کنار گذاشته‌شده برای بدهی ${target.personName}',
      ));
      return '${PersianFormat.money(amount)} برای بدهی ${target.personName} کنار گذاشته شد.';
    }

    final plans = plannedExpenseRepository?.activeItems ?? [];
    if (plans.isEmpty) return 'هزینه آینده فعالی پیدا نکردم.';
    final target = plans.first;
    await allocations.add(MoneyAllocation(
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
    final repo = debtRepository;
    if (repo == null) return 'بخش بدهی هنوز به فرمان صوتی وصل نشده است.';

    final activeDebts = repo.activeItems.where((e) => e.type == DebtType.debt).toList();
    if (activeDebts.isEmpty) return 'بدهی فعالی برای پرداخت پیدا نکردم.';

    DebtItem? best;
    for (final item in activeDebts) {
      if (text.contains(item.personName)) {
        best = item;
        break;
      }
    }
    best ??= activeDebts.first;

    final amount = _parseAmount(text);
    final payment = amount > 0 ? amount : best.remainingAmount;
    await repo.addPayment(best.id, payment);
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

  /// استخراج چند نام از «به علی و محمد و حسن بدهکارم».
  /// اگر فقط یک نام باشد (یا الگو پیدا نشود) لیست خالی برمی‌گردد.
  List<String> _extractMultiDebtPersons(String text) {
    final normalized = _normalize(text);
    final match = RegExp(r'به\s+(.+?)\s+بدهکارم').firstMatch(normalized);
    if (match == null) return const [];

    final rawNames = match.group(1)!;
    // جدا کردن با «و» — ولی «و» داخل مبالغ (مثل «بیست و پنج») نیست چون
    // این بخش قبل از «بدهکارم» فقط نام‌ها را دارد.
    final names = rawNames
        .split('و')
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty && n.length <= 20)
        .toList();
    return names.length >= 2 ? names : const [];
  }

  /// ثبت دسته‌ای چند بدهی + محاسبهٔ فوری برنامهٔ پرداخت.
  Future<String> _handleMultiDebtCommand(
      String rawText, String text, List<String> persons) async {
    final repo = debtRepository;
    if (repo == null) return 'بخش بدهی و طلب هنوز به فرمان صوتی وصل نشده است.';

    final dueAt = _guessDueAt(text) ?? DateTime.now().add(const Duration(days: 30));
    final type = _containsAny(text, ['طلب دارم', 'ازش طلب دارم'])
        ? DebtType.receivable
        : DebtType.debt;

    // برای هر نام، مبلغ مخصوصش را پیدا کن («به علی ۲۰ میل، به محمد پنج میل»)
    final registered = <String, int>{};
    for (final person in persons) {
      final amount = _extractAmountForPerson(text, person);
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
      await repo.add(item);
      registered[person] = amount;
    }

    if (registered.isEmpty) {
      return 'چند نفر را شنیدم ولی مبلغ‌ها را کامل نفهمیدم. مثال: «به علی و محمد بدهکارم، به علی ۲۰ میلیون، به محمد پنج میلیون، تا ماه آینده».';
    }

    // ── محاسبهٔ برنامهٔ پرداخت ──
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

  /// پیدا کردن مبلغ اختصاصی یک شخص: «به <نام> <مبلغ>».
  int? _extractAmountForPerson(String text, String person) {
    final normalized = _normalize(text);
    final match = RegExp('به\\s*$person\\s*(.+?)(?=به\\s|\\،|،|\\.|$)')
        .firstMatch(normalized);
    if (match == null) return null;
    final segment = match.group(1)!;
    final amount = _parseAmount(segment);
    return amount > 0 ? amount : null;
  }

  Future<String> _handleDebtCommand(String rawText, String text) async {
    final repo = debtRepository;
    if (repo == null) return 'بخش بدهی و طلب هنوز به فرمان صوتی وصل نشده است.';

    final amount = _parseAmount(text);
    if (amount <= 0) {
      return 'مبلغ بدهی یا طلب را نفهمیدم. مثلاً بگو: به ممد یک میلیون بدهکارم تا دو روز دیگه باید پس بدم.';
    }

    final type = _containsAny(text, ['طلب دارم', 'ازش طلب دارم']) ? DebtType.receivable : DebtType.debt;
    final person = _extractPersonNameForDebt(text, type);
    final dueAt = _guessDueAt(text) ?? DateTime.now().add(const Duration(days: 2));
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
    await repo.add(item);
    await conversationMemory?.rememberEntity(type: 'debt', id: item.id, title: item.personName);

    final status = const DebtPlanningService().statusFor(item, financeRepository);
    return '${type.faLabel} ${item.personName} به مبلغ ${PersianFormat.money(amount)} با مهلت ${PersianFormat.jalaliLong(dueAt)} ثبت شد. ${status.message} اگر یک روز کمتر درآمد داشته باشی، محاسبه روزهای بعدی با باقی‌مانده جدید خودکار به‌روز می‌شود.';
  }

  Future<String> _handlePlannedExpenseCommand(String rawText, String text) async {
    final repo = plannedExpenseRepository;
    if (repo == null) return 'بخش هزینه‌های آینده هنوز به فرمان صوتی وصل نشده است.';

    final amount = _parseAmount(text);
    if (amount <= 0) {
      return 'مبلغ هزینه را نفهمیدم. مثلاً بگو: هفته دیگه می‌خوام برم بیرون و یک میلیون تومان خرج داره.';
    }

    final dueAt = _guessDueAt(text) ?? DateTime.now().add(const Duration(days: 7));
    final title = _cleanPlannedExpenseTitle(rawText);
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
    await repo.add(item);

    final status = const GoalPlanningService().statusFor(item, financeRepository);
    return 'برنامه هزینه «${item.title}» با مبلغ ${PersianFormat.money(amount)} برای ${PersianFormat.jalaliLong(dueAt)} ثبت شد. ${status.message} اگر یک روز کمتر درآمد داشته باشی، روزهای بعدی خودکار با باقی‌مانده جدید محاسبه می‌شود.';
  }

  Future<String> _handleGoalCommand(String text) async {
    final goals = goalRepository;
    if (goals == null) return 'بخش هدف‌ها هنوز به فرمان صوتی وصل نشده است.';

    final amount = _parseAmount(text);
    if (amount <= 0) {
      return 'مبلغ هدف را نفهمیدم. مثلاً بگو: هدف درآمد روزانه یک میلیون تومان.';
    }

    if (_containsAny(text, ['ماهانه', 'ماه شمسی', 'این ماه'])) {
      await goals.setMonthlyIncomeGoal(amount);
      return 'هدف درآمد ماه شمسی روی ${PersianFormat.money(amount)} تنظیم شد.';
    }

    await goals.setDailyIncomeGoal(amount);
    return 'هدف درآمد روزانه روی ${PersianFormat.money(amount)} تنظیم شد.';
  }

  String _incomeGapAnswer() {
    final goals = goalRepository;
    if (goals == null || goals.dailyIncomeGoal <= 0) {
      return 'برای محاسبه زمان لازم، اول هدف درآمد روزانه را تنظیم کن. مثلاً بگو: هدف درآمد روزانه یک میلیون تومان.';
    }

    final gap = goals.dailyIncomeGoal - financeRepository.incomeToday();
    if (gap <= 0) return 'هدف درآمد امروزت کامل شده است.';

    final hourly = financeRepository.averageHourlyRate();
    if (hourly <= 0) {
      return 'هنوز میانگین درآمد ساعتی ندارم. چند کار درآمدزا را با زمان واقعی و مبلغ درآمد ثبت کن تا دقیق حساب کنم.';
    }

    final minutes = (gap / hourly * 60).ceil();
    return 'برای رسیدن به هدف امروز، حدود ${PersianFormat.money(gap)} دیگر نیاز داری؛ با میانگین فعلی یعنی حدود ${PersianFormat.minutes(minutes)} کار درآمدزا.';
  }

  Future<String> _addTaskByVoice(String rawText, String normalized) async {
    final dueAt = _guessDueAt(normalized);
    final title = _cleanTaskTitle(rawText);

    if (title.isEmpty || title.length < 3) {
      return 'عنوان کار را نفهمیدم. مثلاً بگو: کار جدید تماس با مشتری اضافه کن.';
    }

    final now = DateTime.now();
    final task = Task(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      category: _looksLikeWork(normalized) ? 'کار' : 'ثبت صوتی',
      createdAt: now,
      dueAt: dueAt,
      importance: _containsAny(normalized, ['خیلی مهم', 'فوری', 'ضروری']) ? 5 : 3,
      energy: _containsAny(normalized, ['سخت', 'تمرکز', 'سنگین']) ? EnergyLevel.high : EnergyLevel.medium,
      estimatedMinutes: _guessMinutes(normalized),
      isPinned: _containsAny(normalized, ['فوری', 'خیلی مهم']),
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
      final score = _wordOverlap(_normalize(task.title), text);
      if (score > bestScore) {
        bestScore = score;
        best = task;
      }
    }

    best ??= (openTasks..sort((a, b) => _planner.priorityScore(b).compareTo(_planner.priorityScore(a)))).first;
    final minutes = _guessMinutes(text, fallback: best.estimatedMinutes);
    await taskRepository.complete(best.id, actualMinutes: minutes);
    await notificationService?.cancelTaskReminder(best.id);

    final amount = _parseAmount(text);
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

  String _extractPersonNameForDebt(String text, DebtType type) {
    final normalized = _normalize(text);

    if (type == DebtType.debt) {
      final toMatch = RegExp(r'به\s+(\S+)').firstMatch(normalized);
      if (toMatch != null) return toMatch.group(1) ?? '';
      final debtMatch = RegExp(r'(\S+)\s+(یک|یه|دو|سه|چهار|پنج|شش|شیش|هفت|هشت|نه|ده|\d+)').firstMatch(normalized);
      if (debtMatch != null) return debtMatch.group(1) ?? '';
    } else {
      final fromMatch = RegExp(r'از\s+(\S+)').firstMatch(normalized);
      if (fromMatch != null) return fromMatch.group(1) ?? '';
    }

    return '';
  }

  String _cleanPlannedExpenseTitle(String rawText) {
    var title = _normalize(rawText);
    final patterns = [
      r'هفته دیگه',
      r'هفته بعد',
      r'امروز',
      r'فردا',
      r'میخام',
      r'میخوام',
      r'می‌خوام',
      r'می خوام',
      r'خرج داره',
      r'هزینه داره',
      r'یک میلیون',
      r'یه میلیون',
      r'\d+\s*(میلیون|هزار|تومان|تومن|ریال)?',
      r'و',
    ];
    for (final pattern in patterns) {
      title = title.replaceAll(RegExp(pattern), ' ');
    }
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanTaskTitle(String rawText) {
    var title = _normalize(rawText);
    final patterns = [
      r'کار جدید',
      r'کار جدید',
      r'وظیفه جدید',
      r'اضافه کن',
      r'ثبت کن',
      r'یادم بنداز',
      r'که',
      r'برای امروز',
      r'برای فردا',
      r'امروز',
      r'فردا',
      r'این هفته',
      r'خیلی مهم',
      r'فوری',
      r'ضروری',
      r'ساعت\s+\S+',
      r'تا\s+\S+\s+(دقیقه|ساعت)\s+(دیگه|دیگر)',
    ];
    for (final pattern in patterns) {
      title = title.replaceAll(RegExp(pattern), ' ');
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title;
  }

  DateTime? _guessDueAt(String text) {
    final now = DateTime.now();

    // ── مهلت‌های «ماه» ──
    // «تا ماه آینده» / «ماه دیگه» / «ماه بعد» → آخر ماه بعد
    if (_containsAny(text, ['تا ماه آینده', 'ماه آینده', 'ماه دیگه', 'ماه بعد', 'تا ماه دیگه'])) {
      final next = DateTime(now.year, now.month + 1, 1);
      return DateTime(next.year, next.month + 1, 0, 23, 59);
    }
    // «تا ۲ ماه دیگه» / «تا ۱ ماه دیگر»
    final monthsDigit = RegExp(r'تا\s+(\d+)\s*ماه\s*(دیگه|دیگر|بعد)?').firstMatch(text);
    if (monthsDigit != null) {
      final m = int.parse(monthsDigit.group(1)!);
      final target = DateTime(now.year, now.month + m, 1);
      return DateTime(target.year, target.month + 1, 0, 23, 59);
    }
    final monthsWord = RegExp(r'تا\s+(\S+)\s*ماه\s*(دیگه|دیگر|بعد)?').firstMatch(text);
    if (monthsWord != null) {
      final m = _parseSmallNumber(monthsWord.group(1)!);
      if (m != null) {
        final target = DateTime(now.year, now.month + m, 1);
        return DateTime(target.year, target.month + 1, 0, 23, 59);
      }
    }

    final relativeMinutes = RegExp(r'تا\s+(\d+)\s*(دقیقه|مین)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeMinutes != null) {
      return now.add(Duration(minutes: int.parse(relativeMinutes.group(1)!)));
    }

    final relativeHours = RegExp(r'تا\s+(\d+)\s*(ساعت)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeHours != null) {
      return now.add(Duration(hours: int.parse(relativeHours.group(1)!)));
    }

    final relativeDaysDigit = RegExp(r'تا\s+(\d+)\s*(روز)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeDaysDigit != null) {
      return now.add(Duration(days: int.parse(relativeDaysDigit.group(1)!)));
    }

    final relativeDaysWord = RegExp(r'تا\s+(\S+)\s*(روز)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeDaysWord != null) {
      final days = _parseSmallNumber(relativeDaysWord.group(1)!);
      if (days != null) return now.add(Duration(days: days));
    }

    final plainDaysDigit = RegExp(r'(\d+)\s*(روز)\s*(دیگه|دیگر)').firstMatch(text);
    if (plainDaysDigit != null) {
      return now.add(Duration(days: int.parse(plainDaysDigit.group(1)!)));
    }

    final plainDaysWord = RegExp(r'(\S+)\s*(روز)\s*(دیگه|دیگر)').firstMatch(text);
    if (plainDaysWord != null) {
      final days = _parseSmallNumber(plainDaysWord.group(1)!);
      if (days != null) return now.add(Duration(days: days));
    }

    var baseDate = DateTime(now.year, now.month, now.day);
    var hasDate = false;
    if (text.contains('فردا')) {
      final tomorrow = now.add(const Duration(days: 1));
      baseDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      hasDate = true;
    } else if (text.contains('امروز')) {
      hasDate = true;
    } else if (text.contains('هفته دیگه') || text.contains('هفته بعد') || text.contains('این هفته')) {
      return now.add(const Duration(days: 7));
    }

    final hour = _extractHour(text);
    if (hour != null) {
      var fixedHour = hour;
      if ((text.contains('عصر') || text.contains('شب') || text.contains('بعد از ظهر')) && fixedHour < 12) {
        fixedHour += 12;
      }
      if (!hasDate && fixedHour <= now.hour) {
        baseDate = baseDate.add(const Duration(days: 1));
      }
      return DateTime(baseDate.year, baseDate.month, baseDate.day, fixedHour.clamp(0, 23).toInt());
    }

    if (hasDate) return DateTime(baseDate.year, baseDate.month, baseDate.day, 22);
    return null;
  }

  int? _extractHour(String text) {
    final normalized = _convertPersianDigits(text);
    final digitAfter = RegExp(r'ساعت\s+(\d{1,2})').firstMatch(normalized);
    if (digitAfter != null) return int.parse(digitAfter.group(1)!);

    final wordAfter = RegExp(r'ساعت\s+(\S+)').firstMatch(normalized);
    if (wordAfter != null) return _parseSmallNumber(wordAfter.group(1)!);
    return null;
  }

  int? _parseSmallNumber(String value) {
    final normalized = _convertPersianDigits(value);
    final digit = int.tryParse(normalized);
    if (digit != null) return digit;
    return _numberWords[normalized];
  }

  int _guessMinutes(String text, {int fallback = 30}) {
    final normalized = _convertPersianDigits(text);
    final minuteMatch = RegExp(r'(\d+)\s*(دقیقه|مین|minute)').firstMatch(normalized);
    if (minuteMatch != null) return int.parse(minuteMatch.group(1)!).clamp(5, 24 * 60).toInt();

    final hourMatch = RegExp(r'(\d+)\s*(ساعت|hour)').firstMatch(normalized);
    if (hourMatch != null) return (int.parse(hourMatch.group(1)!) * 60).clamp(5, 24 * 60).toInt();

    if (text.contains('کوتاه') || text.contains('سریع')) return 15;
    if (text.contains('طولانی') || text.contains('زیاد')) return 90;
    return fallback;
  }

  int? _parseAmbiguousSpokenAmount(String text) {
    final normalized = _normalize(text);
    // در فارسی محاوره‌ای «پونصد» معمولاً یعنی ۵۰۰ هزار تومان؛ چون مبهم است با تأیید اجرا می‌کنیم.
    if (_containsAny(normalized, ['پونصد', 'پانصد']) && !_containsAny(normalized, ['هزار', 'میلیون', 'تومان', 'تومن', 'ریال'])) {
      return 500000;
    }
    if (_containsAny(normalized, ['صد']) && !_containsAny(normalized, ['هزار', 'میلیون', 'تومان', 'تومن', 'ریال'])) {
      return 100000;
    }
    return null;
  }

  int _parseAmount(String text) {
    final normalized = _normalize(text).replaceAll(',', '').replaceAll('٬', '');

    final digitMatches = RegExp(r'(\d+)\s*(میلیون|هزار|تومان|تومن|ریال)?').allMatches(normalized).toList();
    for (final match in digitMatches) {
      var amount = int.parse(match.group(1)!);
      final suffix = match.group(2) ?? '';
      if (suffix.contains('میلیون')) return amount * 1000000;
      if (suffix.contains('هزار')) return amount * 1000;
      if (suffix.contains('ریال')) return (amount / 10).round();
      if (suffix.contains('تومان') || suffix.contains('تومن') || amount >= 1000) return amount;
    }

    final words = normalized.split(RegExp(r'\s+'));
    var total = 0;
    var current = 0;
    var sawMoneyScale = false;

    for (final rawWord in words) {
      final word = rawWord.trim();
      if (word == 'و') continue;

      final value = _numberWords[word];
      if (value != null) {
        current += value;
        continue;
      }

      if (word.contains('میلیون')) {
        total += (current == 0 ? 1 : current) * 1000000;
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      if (word.contains('هزار')) {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      if (word.contains('ریال')) {
        total += (current / 10).round();
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      if (word.contains('تومان') || word.contains('تومن')) {
        total += current;
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      // اگر کلمه غیرعددی آمد، احتمالاً عدد قبلی مربوط به ساعت/زمان بوده نه پول.
      current = 0;
    }

    if (sawMoneyScale) return total + current;
    return 0;
  }

  int _wordOverlap(String a, String b) {
    final aw = a.split(' ').where((w) => w.length > 2).toSet();
    final bw = b.split(' ').where((w) => w.length > 2).toSet();
    return aw.intersection(bw).length;
  }

  bool _looksLikeWork(String text) {
    return _containsAny(text, [
      'کار',
      'درآمد',
      'پروژه',
      'مشتری',
      'فروش',
      'فریلنس',
      'تدریس',
      'شیفت',
      'قرارداد',
      'سفارش',
    ]);
  }

  bool _containsAny(String text, List<String> words) => words.any(text.contains);

  String _normalize(String value) {
    return _convertPersianDigits(value)
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'[،,.!؟?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _convertPersianDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return result;
  }

  static const Map<String, int> _numberWords = {
    'صفر': 0,
    'یک': 1,
    'یه': 1,
    'دو': 2,
    'سه': 3,
    'چهار': 4,
    'پنج': 5,
    'شش': 6,
    'شیش': 6,
    'هفت': 7,
    'هشت': 8,
    'نه': 9,
    'ده': 10,
    'یازده': 11,
    'دوازده': 12,
    'سیزده': 13,
    'چهارده': 14,
    'پانزده': 15,
    'شانزده': 16,
    'هفده': 17,
    'هجده': 18,
    'نوزده': 19,
    'بیست': 20,
    'سی': 30,
    'چهل': 40,
    'پنجاه': 50,
    'شصت': 60,
    'هفتاد': 70,
    'هشتاد': 80,
    'نود': 90,
    'صد': 100,
    'یکصد': 100,
    'دویست': 200,
    'سیصد': 300,
    'چهارصد': 400,
    'پانصد': 500,
    'ششصد': 600,
    'هفتصد': 700,
    'هشتصد': 800,
    'نهصد': 900,
  };
}
