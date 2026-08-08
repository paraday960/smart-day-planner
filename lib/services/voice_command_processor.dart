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

    // پرداخت بدهی — حالا هم «بدهی» هم «قرض/وام» + «پرداخت» و هم «خورد خورد به فرهاد دادم» را می‌فهمد
    if (_isDebtPaymentIntent(text)) {
      return _handleDebtPaymentCommand(text);
    }

    // پرسش پرونده شخص: «بدهی فرهاد چقدره؟»، «حساب فرهاد»، «مانده فرهاد»، «فرهاد چقدر بدهکارم»
    if (_isPersonDebtQuery(text)) {
      return _handlePersonDebtQuery(rawText, text);
    }

    // اگر فقط اسم گفته شد (مثل «فرهاد») و شخص ناشناس بود، پرونده بساز
    if (VoiceNlu.isSinglePersianName(text.trim()) ||
        _isSinglePersonDebtMention(text)) {
      return _handleSinglePersonMention(rawText, text);
    }

    // پوشش جامع بدهی/طلب/قرض/وام — شامل «قرض کردم/گرفتم/دادم» و «وام گرفتم» و مخفف «میل»
    if (VoiceNlu.containsAny(text, [
      'بدهکارم',
      'بدهکار هستم',
      'بدهی دارم',
      'بدهکار شدم',
      'طلب دارم',
      'ازم طلب داره',
      'ازش طلب دارم',
      'طلبکارم',
      'قرض کردم',
      'قرض گرفتم',
      'قرض داده',
      'قرض دادم',
      'قرضه دارم',
      'وام گرفتم',
      'وام دادم',
      'پول قرض',
      'پول گرفتم از',
      'قرضه'
    ])) {
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

    if (VoiceNlu.containsAny(text, [
      'کار جدید',
      'وظیفه جدید',
      'اضافه کن',
      'ثبت کن',
      'یادم بنداز',
      'کار دارم',
      'قرار دارم',
      'جلسه دارم',
      'کلاس دارم',
      'شیفت دارم',
      'قرار کاری',
      'جلسه کاری'
    ]) ||
        _isImplicitTask(text)) {
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

    if (pending.type == 'person_creation') {
      final personName = pending.slots['personName'] as String? ?? 'نامشخص';
      // اگر گفت «پرونده رو بساز» بدون مبلغ، فقط پرونده خالی بساز (یادآوری)
      if (VoiceNlu.containsAny(text, ['پرونده', 'بساز', 'درست کن']) && VoiceNlu.parseAmount(text) <= 0) {
        await memory.rememberEntity(type: 'person', id: personName, title: personName);
        await memory.clearPending();
        return 'پرونده «$personName» ساخته شد 📁. از این به بعد هر بدهی، قرض یا پرداخت خرد برای «$personName» را جداگانه حساب می‌کنم.\n'
            'الان بگو: «به $personName دو میلیون بدهکارم تا دو روز دیگه» یا «از $personName یک میل قرض گرفتم»';
      }
      // اگر مبلغ داشت، سعی کن بدهی برای همان شخص بسازی
      final amount = VoiceNlu.parseAmount(text);
      if (amount > 0) {
        String enrichedText = text;
        String enrichedRaw = rawText;
        if (!text.contains(personName)) {
          enrichedText = 'به $personName $text';
          enrichedRaw = 'به $personName $rawText';
        }
        await memory.clearPending();
        // حلقه نده — مستقیم بدهی بساز
        return _handleDebtCommand(enrichedRaw, enrichedText);
      }
      // اگر «بله/آره» گفت، بپرس جزئیات
      if (VoiceNlu.containsAny(text, ['بله', 'آره', 'بساز', 'اوکی', 'درست کن'])) {
        return 'باشه، برای «$personName» چقدر و تا کی؟ مثلاً: «به $personName دو میلیون بدهکارم تا دو روز دیگه»';
      }
      if (_isNegative(text)) {
        await memory.clearPending();
        return 'باشه، پرونده «$personName» نساختم.';
      }
      return 'برای «$personName» بگو چقدر بدهکاری و تا کی؟ مثلاً: «به $personName دو میلیون بدهکارم تا دو روز دیگه» یا بگو «پرونده $personName رو بساز»';
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
    return VoiceNlu.containsAny(text, [
          'بدهکارم',
          'بدهی دارم',
          'بدهکار شدم',
          'قرض کردم',
          'قرض گرفتم',
          'وام گرفتم',
          'پول گرفتم'
        ]) &&
        VoiceNlu.parseAmount(text) <= 0;
  }

  bool _isDebtPaymentIntent(String text) {
    final hasPaymentVerb = VoiceNlu.containsAny(text, [
      'پرداخت کردم',
      'پس دادم',
      'تسویه کردم',
      'پرداخت دادم',
      'دادم به',
      'واریز کردم'
    ]);
    // حالت کلاسیک: بدهی + پرداخت
    if (VoiceNlu.containsAny(text, ['بدهی', 'قرض', 'وام']) && hasPaymentVerb) return true;
    // حالت خرد: مبلغ + پرداخت + نام شخص شناخته‌شده
    if (hasPaymentVerb && _hasActiveDebtForPersonInText(text)) return true;
    // حالت «خورد خورد» یا «قسط» حتی بدون کلمه بدهی
    if (VoiceNlu.containsAny(text, ['خورد خورد', 'قسط', 'تیکه تیکه']) &&
        (VoiceNlu.containsAny(text, ['پرداخت', 'دادم']) || _hasActiveDebtForPersonInText(text))) {
      return true;
    }
    // حالت ساده: «به فرهاد پرداخت کردم» بدون کلمه بدهی
    if (hasPaymentVerb && VoiceNlu.containsAny(text, ['به ', 'از '])) {
      // اگر متنش شبیه پرداخت به شخص باشد، بدهی حساب کن
      final maybePerson = VoiceNlu.extractPersonNameForQuery(text);
      if (maybePerson.isNotEmpty) return true;
    }
    return false;
  }

  bool _hasActiveDebtForPersonInText(String text) {
    final normalized = VoiceNlu.normalize(text);
    for (final d in debtRepository.activeItems) {
      if (normalized.contains(d.personName)) return true;
    }
    return false;
  }

  bool _isPersonDebtQuery(String text) {
    final normalized = VoiceNlu.normalize(text);
    // الگوهای پرسش پرونده: بدهی فرهاد، حساب فرهاد، مانده فرهاد، پرونده فرهاد، قرض فرهاد
    if (VoiceNlu.containsAny(normalized, ['بدهی', 'قرض', 'وام', 'حساب', 'مانده', 'پرونده'])) {
      final name = VoiceNlu.extractPersonNameForQuery(normalized);
      if (name.isNotEmpty && name.length >= 2) return true;
    }
    // حالت «فرهاد چقدر بدهکارم» یا «فرهاد چقدر طلب دارم»
    if (RegExp(r'\S+\s+چقدر').hasMatch(normalized) &&
        VoiceNlu.containsAny(normalized, ['بدهکار', 'طلب', 'بدهی', 'مانده'])) {
      return true;
    }
    // حالت «وضعیت فرهاد» وقتی فرهاد شناخته شده باشد
    if (VoiceNlu.containsAny(normalized, ['وضعیت', 'اطلاعات', 'نمایش']) &&
        _hasActiveDebtForPersonInText(normalized)) {
      return true;
    }
    return false;
  }

  bool _isSinglePersonDebtMention(String text) {
    final normalized = VoiceNlu.normalize(text).trim();
    // فقط یک اسم + شاید «بدهی» یا «حساب» مختصر
    if (VoiceNlu.isSinglePersianName(normalized)) return true;
    // «فرهاد بدهی» یا «فرهاد حساب»
    if (RegExp(r'^[\u0600-\u06FF]{2,15}\s+(بدهی|حساب|قرض|وام)?$').hasMatch(normalized)) {
      final name = normalized.split(' ').first;
      if (VoiceNlu.isSinglePersianName(name)) return true;
    }
    return false;
  }

  Future<String> _handlePersonDebtQuery(String rawText, String text) async {
    final name = VoiceNlu.extractPersonNameForQuery(text);
    final queryName = name.isEmpty ? VoiceNlu.normalize(text).split(' ').first : name;

    // جستجو در همه بدهی‌ها (فعال و تسویه‌شده) برای آن شخص
    final allForPerson = debtRepository.items
        .where((d) => d.personName == queryName || d.personName.contains(queryName) || queryName.contains(d.personName))
        .toList();
    final activeForPerson = debtRepository.activeItems
        .where((d) => d.personName == queryName || d.personName.contains(queryName) || queryName.contains(d.personName))
        .toList();

    if (allForPerson.isEmpty) {
      // شخص ناشناس — پیشنهاد ساخت پرونده
      await conversationMemory?.setPending('person_creation', {'personName': queryName});
      return '«$queryName» رو هنوز نمی‌شناسم. 🤔\n'
          'می‌خوای براش پرونده بسازم تا از این به بعد همه بدهی‌ها و پرداخت‌های خردش رو جدا حساب کنم؟\n'
          'بگو: «به $queryName دو میلیون بدهکارم تا دو روز دیگه» یا «از $queryName یک میل قرض گرفتم»\n'
          'یا اگر فقط می‌خوای پرونده خالی بسازم، بگو «پرونده $queryName رو بساز»';
    }

    // شخص شناخته‌شده — گزارش کامل
    final totalAmount = allForPerson.fold<int>(0, (s, d) => s + d.amount);
    final totalPaid = allForPerson.fold<int>(0, (s, d) => s + d.paidAmount);
    final totalRemaining = allForPerson.fold<int>(0, (s, d) => s + d.remainingAmount);
    final activeRemaining = activeForPerson.fold<int>(0, (s, d) => s + d.remainingAmount);

    final buffer = StringBuffer();
    buffer.writeln('📁 پرونده «$queryName»:');
    buffer.writeln('• کل بدهی/طلب ثبت‌شده: ${PersianFormat.money(totalAmount)} (${PersianFormat.digits(allForPerson.length)} مورد)');
    buffer.writeln('• کل پرداخت‌شده: ${PersianFormat.money(totalPaid)}');
    buffer.writeln('• مانده فعال: ${PersianFormat.money(activeRemaining)} ${activeForPerson.isEmpty ? '✅ تسویه شده' : '⏳'}');

    if (activeForPerson.isNotEmpty) {
      buffer.writeln('• جزئیات بدهی‌های فعال:');
      for (final d in activeForPerson) {
        final status = const DebtPlanningService().statusFor(d, financeRepository);
        final progress = ((d.paidAmount / d.amount) * 100).round();
        buffer.writeln(
            '  - ${d.type.faLabel} ${PersianFormat.money(d.amount)} → پرداخت ${PersianFormat.money(d.paidAmount)} → مانده ${PersianFormat.money(d.remainingAmount)} (${PersianFormat.digits(progress)}٪ پرداخت) • مهلت ${PersianFormat.jalaliDate(d.dueAt)} • ${status.message}');
      }
    } else {
      buffer.writeln('• همه بدهی‌های $queryName تسویه شده 🎉');
      // نمایش تسویه‌شده‌ها هم
      for (final d in allForPerson.take(2)) {
        buffer.writeln('  - ${d.type.faLabel} ${PersianFormat.money(d.amount)} • تسویه ${PersianFormat.jalaliDate(d.dueAt)}');
      }
    }

    // اگر پرداخت‌های خرد داشته، تاکید کن
    if (totalPaid > 0 && totalPaid < totalAmount) {
      buffer.writeln('💡 خورد خورد پرداخت کردی: ${PersianFormat.money(totalPaid)} از ${PersianFormat.money(totalAmount)} کم شده، ${PersianFormat.money(totalRemaining)} مونده.');
    }

    buffer.writeln('برای پرداخت جدید بگو: «۵۰۰ هزار به $queryName پرداخت کردم»');

    return buffer.toString();
  }

  Future<String> _handleSinglePersonMention(String rawText, String text) async {
    final normalized = VoiceNlu.normalize(text).trim();
    String name = normalized;
    if (VoiceNlu.isSinglePersianName(normalized)) {
      name = normalized;
    } else {
      name = VoiceNlu.extractPersonNameForQuery(text);
      if (name.isEmpty) name = normalized.split(' ').first;
    }
    name = name.replaceAll(RegExp(r'[؟?،,.]'), '').trim();
    if (name.isEmpty || name.length < 2) return 'نام شخص را نفهمیدم. بگو: فرهاد';

    // آیا این شخص را می‌شناسیم؟
    final known = debtRepository.items.any((d) => d.personName == name || d.personName.contains(name));
    if (known) {
      // اگر می‌شناسیم، همان گزارش پرونده را بده
      return _handlePersonDebtQuery(rawText, 'بدهی $name');
    }

    // ناشناس — بپرس کیه و پرونده بساز
    await conversationMemory?.setPending('person_creation', {'personName': name});
    return '«$name» رو نمی‌شناسم. کیه؟ 🤔\n'
        'براش یه پرونده می‌سازم تا از این به بعد بدهی‌ها، قرض‌ها و پرداخت‌های خردش رو جدا حساب کنم.\n'
        'بگو: «به $name چقدر بدهکاری و تا کی؟» مثلاً: «به $name دو میلیون بدهکارم تا دو روز دیگه»\n'
        'یا بگو «پرونده $name رو بساز» تا پرونده خالی براش درست کنم.';
  }

  /// تشخیص جمله‌های طبیعی مثل «فردا ساعت ۲ کار دارم» که باید کار بسازند
  /// ولی کلمهٔ صریح «کار جدید/اضافه کن» ندارند.
  /// برای اینکه سؤال‌هایی مثل «فردا چی کار کنم؟» اشتباهی کار نسازند،
  /// کلمات سؤالی را مستثنی می‌کنیم.
  bool _isImplicitTask(String text) {
    // اگر سؤالی یا درخواست برنامه است، کار نساز
    if (VoiceNlu.containsAny(text, [
      'چی کار کنم',
      'چیکار کنم',
      'چه کار کنم',
      'برنامه',
      'چی عقب',
      'پیشنهاد',
      'راهنما',
      'کمک',
      'وضعیت',
      'ریسک'
    ])) {
      return false;
    }
    final hasDateOrTime = VoiceNlu.containsAny(text, [
      'فردا',
      'امروز',
      'پس فردا',
      'این هفته',
      'هفته دیگه',
      'ساعت',
      'صبح',
      'ظهر',
      'عصر',
      'شب'
    ]);
    final hasTaskKeyword = VoiceNlu.containsAny(text, [
      'کار دارم',
      'قرار دارم',
      'جلسه دارم',
      'کلاس دارم',
      'شیفت دارم'
    ]);
    // حالت خیلی طبیعی: «فردا ساعت ۲ کار دارم» -> hasDateOrTime + hasTaskKeyword
    if (hasDateOrTime && hasTaskKeyword) return true;
    // حالت کوتاه: «ساعت ۲ جلسه» + فردا/امروز
    if (hasDateOrTime &&
        VoiceNlu.containsAny(text, ['قرار', 'جلسه', 'کلاس', 'شیفت']) &&
        text.contains('ساعت')) {
      return true;
    }
    return false;
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
    if (activeDebts.isEmpty) return 'بدهی فعالی برای پرداخت پیدا نکردم. اول بگو: «به فرهاد دو میلیون بدهکارم»';

    // پیدا کردن بهترین بدهی برای پرداخت — اگر نام شخص در متن بود، بدهی‌های همان شخص با نزدیک‌ترین مهلت
    DebtItem? best;
    final candidates = activeDebts.where((d) => text.contains(d.personName)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    if (candidates.isNotEmpty) {
      best = candidates.firstWhere((d) => d.remainingAmount > 0, orElse: () => candidates.first);
    } else {
      // تلاش با استخراج نام از متن (مثل «به فرهاد پرداخت کردم»)
      final maybeName = VoiceNlu.extractPersonNameForQuery(text);
      if (maybeName.isNotEmpty) {
        final named = activeDebts.where((d) => d.personName == maybeName || d.personName.contains(maybeName)).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
        if (named.isNotEmpty) best = named.firstWhere((d) => d.remainingAmount > 0, orElse: () => named.first);
      }
    }
    best ??= (activeDebts..sort((a, b) => a.dueAt.compareTo(b.dueAt))).firstWhere((d) => d.remainingAmount > 0, orElse: () => activeDebts.first);

    var amount = VoiceNlu.parseAmount(text);
    // اگر «خورد خورد» یا مبلغ مبهم بود
    if (amount <= 0) {
      final ambiguous = VoiceNlu.parseAmbiguousSpokenAmount(text);
      if (ambiguous != null && ambiguous > 0) amount = ambiguous;
    }
    // اگر باز هم مبلغ نداشت و «خورد خورد» گفته، بپرس چقدر
    if (amount <= 0 && VoiceNlu.containsAny(text, ['خورد خورد', 'تیکه تیکه', 'قسط', 'کم کم'])) {
      return 'چقدر خورد خورد پرداخت کردی به «${best.personName}»؟ مثلاً بگو: «۵۰۰ هزار به ${best.personName} پرداخت کردم»';
    }
    final payment = amount > 0 ? amount.clamp(1, best.remainingAmount).toInt() : best.remainingAmount;
    await debtRepository.addPayment(best.id, payment);
    await financeRepository.add(
      FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: FinanceTransactionType.expense,
        amount: payment,
        createdAt: DateTime.now(),
        note: 'پرداخت بدهی به ${best.personName} (خورد خورد)',
        category: 'بدهی',
      ),
    );

    // بعد از پرداخت، بدهی را دوباره بخوان تا مانده جدید را بگیری
    final updated = debtRepository.items.firstWhere((d) => d.id == best!.id, orElse: () => best!);
    final remaining = updated.remainingAmount;
    final progress = ((updated.amount - remaining) / updated.amount * 100).round();
    await conversationMemory?.rememberEntity(type: 'debt', id: updated.id, title: updated.personName);

    if (remaining <= 0) {
      return 'پرداخت ${PersianFormat.money(payment)} به «${best.personName}» ثبت شد ✅ بدهی «${best.personName}» کامل تسویه شد! 🎉 خورد خورد همه رو دادی.';
    }
    return 'پرداخت ${PersianFormat.money(payment)} به «${best.personName}» ثبت شد.\n'
        'مانده: ${PersianFormat.money(remaining)} از ${PersianFormat.money(updated.amount)} (${PersianFormat.digits(progress)}٪ پرداخت شده، ${PersianFormat.digits(100 - progress)}٪ مانده)\n'
        'خورد خورد داری کم می‌کنی — ادامه بده! برای دیدن پرونده بگو: «بدهی ${best.personName} چقدره؟»';
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
      // تلاش برای تشخیص مقدار مبهم مثل «پونصد» بدون واحد
      final ambiguous = VoiceNlu.parseAmbiguousSpokenAmount(text);
      if (ambiguous != null && ambiguous > 0) {
        // اگر مبهم بود، با همان منطق تأیید ادامه بده — اینجا فعلاً پیام راهنما می‌دهیم
      }
      return 'مبلغ بدهی یا طلب را نفهمیدم. مثلاً بگو: به ممد یک میلیون بدهکارم تا دو روز دیگه باید پس بدم. (مخفف «میل» هم می‌فهمم: ۲ میل = ۲ میلیون)';
    }

    // تشخیص نوع: طلب (ما باید بگیریم) vs بدهی (ما باید پس بدیم)
    // طلب: «طلب دارم», «قرض دادم», «وام دادم»
    // بدهی: «بدهکارم», «قرض کردم/گرفتم», «وام گرفتم»
    final isReceivable = VoiceNlu.containsAny(text, [
      'طلب دارم',
      'ازش طلب دارم',
      'طلبکارم',
      'قرض دادم',
      'قرض داده',
      'وام دادم',
      'پول دادم'
    ]);
    final isDebt = VoiceNlu.containsAny(text, [
      'بدهکارم',
      'بدهی دارم',
      'بدهکار شدم',
      'قرض کردم',
      'قرض گرفتم',
      'قرضه دارم',
      'وام گرفتم',
      'پول گرفتم',
      'پول قرض'
    ]);
    DebtType type;
    if (isReceivable && !isDebt) {
      type = DebtType.receivable;
    } else if (isDebt && !isReceivable) {
      type = DebtType.debt;
    } else if (text.contains('دادم') && (text.contains('قرض') || text.contains('وام'))) {
      type = DebtType.receivable;
    } else if (text.contains('گرفتم') || text.contains('کردم')) {
      type = DebtType.debt;
    } else {
      type = DebtType.debt;
    }
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
