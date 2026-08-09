import 'dart:async';

import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'feedback_learning_service.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';
import 'debt_repository.dart';
import 'llama_backend.dart';
import 'local_assistant.dart';
import 'local_assistant_memory.dart';
import 'local_feedback_learning.dart';
import 'local_online_router.dart';
import 'persian_nlu.dart';
import 'conversation_router.dart';
import 'skill_service.dart';
import 'voice_nlu.dart';

/// یک پیام در تاریخچهٔ مکالمه.
class ChatTurn {
  ChatTurn({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;
}

/// دستیار گفتگوی هوشمند — تعامل و یادگیری هوش محلی از هوش آنلاین.
///
/// حلقهٔ یادگیری:
/// 1. محلی بلد نیست → از آنلاین می‌پرسد (با دانش یادگرفته‌شدهٔ قبلی در پرامپت)
/// 2. پاسخ آنلاین در حافظهٔ ساختاریافته ذخیره می‌شود (منبع، تاریخ، کیفیت)
/// 3. دفعهٔ بعد همان/سؤال مشابه → مستقیم از محلی (سریع و رایگان)
/// 4. بازخورد کاربر (👍/👎) → امتیاز ورودی را تغییر می‌دهد؛ بازخورد منفی
///    «خوددرمانی» می‌کند: دوباره از آنلاین می‌پرسد و جواب بهتر را جایگزین می‌کند
/// 5. تصحیح کاربر → جواب تمیز و دقیق جایگزین می‌شود (منبع: تصحیح)
class IntelligentAssistantService {
  IntelligentAssistantService({
    required this.online,
    required this.ruleBased,
    required this.finance,
    required this.goal,
    required this.debt,
    LocalAssistantMemory? memory,
    IntentFeedbackStore? feedbackStore,
    ConversationContext? conversationContext,
    LocalOnlineRouter? onlineRouter,
    this.maxHistoryTurns = 8,
    Duration timeout = const Duration(seconds: 40),
  })  : _timeout = timeout,
        memory = memory ?? LocalAssistantMemory.instance,
        feedbackStore = feedbackStore ?? _defaultFeedbackStore,
        conversation = conversationContext ?? ConversationContext(),
        onlineRouter = onlineRouter ?? LocalOnlineRouter();

  final IntentFeedbackStore feedbackStore;

  /// زمینهٔ مکالمه برای پشتیبانی از پیگیری‌های ارجاعی (ادامه‌اش چیه؟).
  final ConversationContext conversation;

  /// تصمیم‌گیرنده بین هوش محلی و آنلاین.
  final LocalOnlineRouter onlineRouter;

  static final IntentFeedbackStore _defaultFeedbackStore =
      IntentFeedbackStore(storageKey: 'intent_feedback_v1');

  final LlmBackend? online;
  final LocalLlmAdapter ruleBased;
  final FinanceRepository finance;
  final GoalRepository goal;
  final DebtRepository debt;
  final Duration _timeout;
  final int maxHistoryTurns;

  /// حافظهٔ یادگیری محلی (سؤال → جواب + متادیتا).
  final LocalAssistantMemory memory;

  /// تاریخچهٔ مکالمه (محدود به [maxHistoryTurns]).
  final List<ChatTurn> _history = [];

  /// کلید (سؤال نرمال‌شده) آخرین ورودی‌ای که از حافظه پاسخ داده شد.
  String? _lastMemoryKey;

  /// آیا پاسخ آخر واقعاً از بک‌اند آنلاین آمده (نه fallback)؟
  bool _lastAnswerFromOnline = false;

  /// برچسب منبع آخرین پاسخ برای نمایش.
  String _lastSourceLabel = '—';

  /// منبع آخرین پاسخ (برای UI).
  String get lastAnswerSourceLabel => _lastSourceLabel;

  String? _lastLocalIntentId;
  String? _lastUserText;

  bool _isCorrection(String text) {
    final norm = VoiceNlu.normalize(text);
    return norm.contains('نه') && (norm.contains('اشتباه') || norm.contains('ببخشید') || norm.contains('غلط')) ||
        norm.startsWith('نه ') ||
        norm.contains('تصحیح');
  }

  /// پاسخ به یک درخواست کاربر (با حافظهٔ مکالمه + یادگیری محلی از آنلاین).
  Future<String> ask({
    required String userText,
    required List<Task> tasks,
  }) async {
    final t = userText.trim();
    if (t.isEmpty) return 'چیزی نشنیدم. بگو چطور می‌توانم کمکت کنم.';

    await memory.load();
    await feedbackStore.load();

    // ── ۰) پیگیری ارجاعی (آنافورا): «ادامه‌اش چیه؟»، «بعدش؟» ──
    // اگر متن یک پیگیری است و سؤال قبلی کاربر وجود دارد، به همان intent/موضوع
    // قبلی رجوع می‌کنیم تا پاسخ مرتبط داده شود.
    final resolved = conversation.resolveFollowUp(t);
    String effectiveText = t;
    if (resolved != null && resolved.intentId.isEmpty) {
      // ارجاع به متن سؤال قبلی (برای انطباق با حافظه/آنلاین)
      effectiveText = resolved.originalText;
    }

    // یادگیری ضمنی: بازنویسی هم‌مضمون سؤال قبلی = شکست پاسخ محلی
    final prevText = _lastUserText;
    final prevIntent = _lastLocalIntentId;
    if (prevText != null &&
        prevIntent != null &&
        !FeedbackLearningService.isFeedback(t) &&
        !_isCorrection(PersianNormalizer.normalize(t)) &&
        _isRephrase(prevText, t)) {
      feedbackStore.recordFailure(prevIntent);
    }
    _lastUserText = t;
    // توجه: _lastLocalIntentId اینجا صفر نمی‌شود تا اگر کاربر این نوبت را تصحیح
    // کرد، بتوان شکست intent محلی قبلی را ثبت کرد. بعد از پاسخ این نوبت بازنشانی می‌شود.

    // ── ۱) یادگیری تقویتی از بازخورد کاربر ──
    // اگر کاربر بعد از یک پاسخ «خوب بود» / «بد بود» بگوید و آن پاسخ از
    // حافظه آمده باشد، امتیاز ورودی حافظه تغییر می‌کند. بازخورد منفی
    // باعث «خوددرمانی» می‌شود: دوباره از آنلاین پرسیده و جواب بهتر می‌آید.
    if (_history.isNotEmpty &&
        _history.last.role == 'assistant' &&
        FeedbackLearningService.isFeedback(t)) {
      final fb = FeedbackLearningService.detectFromText(t);
      if (fb != FeedbackType.neutral && _lastMemoryKey != null) {
        final updated = await memory.rate(
          _lastMemoryKey!,
          positive: fb == FeedbackType.positive,
        );
        _history.add(ChatTurn(role: 'user', content: t));
        String ack;
        if (fb == FeedbackType.positive) {
          // ignore: unawaited_futures
          SkillService.instance.addPoints(2, 'بازخورد مثبت روی یادگیری');
          ack = 'ممنون! این پاسخ را قوی‌تر به خاطر سپردم 💪';
        } else if (updated == null) {
          // ورودی کاملاً بی‌اعتبار شد و حذف گردید
          ack = 'متوجه شدم؛ این یادگیری اشتباه بود و حذفش کردم. سؤال را دوباره بپرس تا از نو یاد بگیرم.';
        } else {
          // خوددرمانی: پرسش دوباره از آنلاین و جایگزینی جواب
          await _selfHeal(_lastMemoryKey!, tasks);
          // ignore: unawaited_futures
          SkillService.instance.addPoints(5, 'خوددرمانی از بازخورد');
          ack = 'متوجه شدم؛ از هوش آنلاین جواب بهتری گرفتم و جایگزینش کردم.';
        }
        _history.add(ChatTurn(role: 'assistant', content: ack));
        _lastMemoryKey = null;
        _lastSourceLabel = 'بازخورد';
        return ack;
      }
    }

    // ── ۲) یادگیری از تصحیح کاربر ──
    // اگر کاربر بعد از جواب محلی بگوید "نه اشتباهه، ۱M بود" و عدد جدید
    // بدهد، حافظه با جواب تمیز و تصحیح‌شده به‌روز می‌شود (منبع: تصحیح)
    // و همان‌جا تأیید داده می‌شود (متن تصحیح سؤال جدید نیست).
    if (_isCorrection(t) && _history.isNotEmpty && _history.last.role == 'assistant') {
      final lastUserIndex = _history.lastIndexWhere((e) => e.role == 'user');
      if (lastUserIndex != -1) {
        final lastUserQ = _history[lastUserIndex].content;
        final newAmount = VoiceNlu.parseAmount(t);
        // اگر کاربر عدد جدید یا نام جدید داد، همان سؤال قبلی را با پاسخ تصحیح‌شده به‌روز کن
        if (newAmount > 0 || VoiceNlu.extractPersonNameForQuery(t).isNotEmpty) {
          final correctedAnswer = _buildCorrectedAnswer(t, newAmount);
          await memory.updateAnswer(
            lastUserQ,
            correctedAnswer,
            source: MemorySource.correction,
            feedbackScore: 0.3,
          );
          // اگر پاسخ قبلی از حافظه با کلید متفاوت آمده بود، آن ورودی را هم اصلاح کن
          if (_lastMemoryKey != null &&
              _lastMemoryKey != memory.normalizeQuestion(lastUserQ)) {
            await memory.updateEntryByKey(
              _lastMemoryKey!,
              correctedAnswer,
              source: MemorySource.correction,
              feedbackScore: 0.3,
            );
          }
          if (_lastLocalIntentId != null) {
            feedbackStore.recordFailure(_lastLocalIntentId!);
            _lastLocalIntentId = null;
          }
          // ignore: unawaited_futures
          SkillService.instance.addPoints(7, 'یادگیری از تصحیح');
          _history.add(ChatTurn(role: 'user', content: t));
          const ack = 'تصحیح شد! این را یاد گرفتم و از حالا درست جواب می‌دهم ✏️';
          _history.add(ChatTurn(role: 'assistant', content: ack));
          _lastMemoryKey = memory.normalizeQuestion(lastUserQ);
          _lastSourceLabel = 'تصحیح';
          return ack;
        }
      }
    }

    _history.add(ChatTurn(role: 'user', content: t));
    // محدود کردن تاریخچه
    if (_history.length > maxHistoryTurns) {
      _history.removeRange(0, _history.length - maxHistoryTurns);
    }

    String answer;
    final fromMemory = memory.lookupEntry(effectiveText);
    if (fromMemory != null) {
      // دستیار این سؤال را «یاد گرفته» — مستقیم از محلی جواب بده.
      answer = fromMemory.answer;
      _lastMemoryKey = fromMemory.question;
      _lastSourceLabel = 'حافظهٔ محلی (یادگیری از آنلاین)';
      // ثبت استفاده برای تقویت ورودی + امتیاز مهارت
      // ignore: unawaited_futures
      memory.recordHit(effectiveText);
      // ignore: unawaited_futures
      SkillService.instance.addForScenarioReuse();
    } else {
      _lastMemoryKey = null;
      final intentMatch = _extractLocalIntent(t);
      final localCanHandle = _localCanAnswerMeaningfully(t);
      final stats = intentMatch != null
          ? feedbackStore.stats[intentMatch]
          : null;
      final route = onlineRouter.decide(
        text: effectiveText,
        localConfidence: intentMatch != null
            ? _confidenceOf(t)
            : null,
        localCanHandle: localCanHandle,
        localSuccessCount: stats?.success ?? 0,
        localFailureCount: stats?.failure ?? 0,
      );
      final onlineAvailable = route != RouteTarget.localOnly &&
          await _isOnlineAvailable();

      if (route == RouteTarget.localOnly ||
          (route == RouteTarget.localFirst && localCanHandle) ||
          (localCanHandle && !onlineAvailable)) {
        // اگر مسیریاب، پیگیری ارجاعی را به یک intent خاص وصل کرد، همان را اجرا کن.
        final followIntent =
            resolved?.intentId.isNotEmpty == true ? resolved!.intentId : null;
        if (followIntent != null && ruleBased is RuleBasedLocalAssistant) {
          answer = await (ruleBased as RuleBasedLocalAssistant)
              .answerIntent(followIntent, tasks);
          _lastSourceLabel = 'هوش محلی (پیگیری)';
          _lastLocalIntentId = followIntent;
          feedbackStore.recordSuccess(followIntent);
        } else {
          answer = await ruleBased.generate(prompt: t, tasks: tasks);
          _lastSourceLabel = 'هوش محلی';
          final intentId = _extractLocalIntentId(t);
          if (intentId != null) {
            _lastLocalIntentId = intentId;
            feedbackStore.recordSuccess(intentId);
          }
        }
      } else if (route == RouteTarget.online && onlineAvailable) {
        // محلی کافی نیست یا سؤال پیچیده است → آنلاین.
        _lastAnswerFromOnline = false;
        answer = await _askOnline(effectiveText, tasks);
        if (_lastAnswerFromOnline) {
          // فقط پاسخ واقعی آنلاین یاد گرفته می‌شود (fallback نه)
          await memory.rememberEntry(
            effectiveText,
            answer,
            source: MemorySource.online,
          );
          if (effectiveText != t) {
            await memory.rememberEntry(
              t,
              answer,
              source: MemorySource.online,
            );
          }
          _lastMemoryKey = memory.normalizeQuestion(effectiveText);
          _lastSourceLabel = 'هوش آنلاین (یاد گرفته شد)';
          // امتیاز مهارت برای یادگیری جدید
          // ignore: unawaited_futures
          SkillService.instance.addForLocalAnswer(question: t);
        } else {
          _lastSourceLabel = 'هوش قانونی (آنلاین خطا داد)';
        }
      } else {
        // آنلاین هم در دسترس نیست. اگر محلی پاسخی برای این سؤال دارد بده،
        // در غیر این صورت پیام واضح بده (نه پاسخ تکراری/نامرتبط).
        if (localCanHandle) {
          answer = await ruleBased.generate(prompt: t, tasks: tasks);
        } else {
          answer = 'این سؤال به داده‌های برنامه مربوط نیست و هوش آنلاین '
              'هم در دسترس نیست. اگر کلید آنلاین را در تنظیمات وارد کنید، '
              'به هر سؤالی پاسخ می‌دهم و یاد می‌گیرم.';
        }
        _lastSourceLabel = 'هوش قانونی';
      }
    }

    _history.add(ChatTurn(role: 'assistant', content: answer));
    // ثبت نوبت در زمینهٔ مکالمه برای پشتیبانی از پیگیری‌های بعدی.
    final resolvedIntent = _lastLocalIntentId;
    conversation.addUser(effectiveText, intentId: resolvedIntent);
    conversation.addAssistant(answer, intentId: resolvedIntent);
    return answer;
  }

  /// «خوددرمانی»: پرسش دوباره از آنلاین و جایگزینی جواب بی‌اعتبار.
  Future<void> _selfHeal(String question, List<Task> tasks) async {
    final backend = online;
    if (backend == null) return;
    try {
      if (!await backend.available) return;
      final prompt = _buildPrompt(question, _buildContext(tasks));
      final newAnswer = await backend.generate(prompt).timeout(_timeout);
      if (newAnswer.trim().isNotEmpty) {
        await memory.updateEntryByKey(
          question,
          newAnswer,
          source: MemorySource.online,
          feedbackScore: 0.2,
        );
      }
    } catch (_) {
      // خوددرمانی ناموفق — ورودی با امتیاز کاهش‌یافته باقی می‌ماند
    }
  }

  /// ساخت جواب تمیز از متن تصحیح کاربر (به‌جای ذخیرهٔ متن خام).
  String _buildCorrectedAnswer(String correctionText, int amount) {
    if (amount > 0) {
      return 'طبق تصحیح شما، مبلغ درست ${PersianFormat.money(amount)} است.';
    }
    final clean = correctionText
        .replaceAll(
            RegExp(r'^(نه|نخیر|اشتباهه|اشتباه|غلطه|غلط|ببخشید|ببخش)\s*'),
            '')
        .trim();
    return clean.isEmpty ? 'تصحیح کاربر ثبت شد.' : 'تصحیح: $clean';
  }

  Future<bool> _isOnlineAvailable() async {
    final backend = online;
    if (backend == null) return false;
    try {
      return await backend.available;
    } catch (_) {
      return false;
    }
  }

  /// پرسش از هوش آنلاین با context کامل برنامه + دانش یادگرفته‌شدهٔ قبلی.
  Future<String> _askOnline(String userText, List<Task> tasks) async {
    final context = _buildContext(tasks);
    final prompt = _buildPrompt(userText, context);
    try {
      final answer = await online!
          .generate(prompt)
          .timeout(_timeout, onTimeout: () => _ruleBasedAnswer(userText, tasks));
      _lastAnswerFromOnline = true;
      return answer;
    } catch (_) {
      return _ruleBasedAnswer(userText, tasks);
    }
  }

  Future<String> _ruleBasedAnswer(String text, List<Task> tasks) async {
    try {
      return await ruleBased.generate(prompt: text, tasks: tasks);
    } catch (_) {
      return 'نتوانستم پاسخی آماده کنم. لطفاً دوباره سؤال کن.';
    }
  }

  /// ساخت context از داده‌های واقعی برنامه.
  String _buildContext(List<Task> tasks) {
    final b = StringBuffer();

    // کارها
    b.writeln('کارهای باز کاربر:');
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) {
      b.writeln('  (هیچ کار بازی نیست)');
    } else {
      for (final task in open.take(10)) {
        final due = task.dueAt != null
            ? '، مهلت ${PersianFormat.jalaliLong(task.dueAt!)}'
            : '';
        b.writeln(
            '  - ${task.title} (اهمیت ${task.importance}/۵، تخمین ${task.estimatedMinutes} دقیقه$due)');
      }
    }
    b.writeln();

    // مالی
    final txns = finance.transactions;
    final totalIncome = finance.total(type: FinanceTransactionType.income);
    final totalExpense = finance.total(type: FinanceTransactionType.expense);
    final balance = finance.net();
    b.writeln('وضعیت مالی:');
    b.writeln('  درآمد کل: ${PersianFormat.money(totalIncome)}');
    b.writeln('  هزینه کل: ${PersianFormat.money(totalExpense)}');
    b.writeln('  موجودی (درآمد-هزینه): ${PersianFormat.money(balance)}');
    if (txns.isNotEmpty) {
      b.writeln('  آخرین تراکنش‌ها:');
      for (final t in txns.take(5)) {
        final sign = t.type == FinanceTransactionType.income ? '+' : '-';
        b.writeln(
            '    ${t.createdAt.toLocal().toString().substring(0, 10)}: $sign${PersianFormat.money(t.amount)} ${t.note.isNotEmpty ? '(${t.note})' : ''}');
      }
    }
    b.writeln();

    // اهداف
    if (goal.dailyIncomeGoal > 0 || goal.monthlyIncomeGoal > 0) {
      b.writeln('اهداف درآمدی:');
      if (goal.dailyIncomeGoal > 0) {
        b.writeln(
            '  هدف روزانه: ${PersianFormat.money(goal.dailyIncomeGoal)} (تا الان ${PersianFormat.money(finance.incomeToday())})');
      }
      if (goal.monthlyIncomeGoal > 0) {
        b.writeln(
            '  هدف ماهانه: ${PersianFormat.money(goal.monthlyIncomeGoal)} (تا الان ${PersianFormat.money(finance.incomeThisMonth())})');
      }
      b.writeln();
    }

    // بدهی‌ها
    final debts = debt.activeItems;
    if (debts.isNotEmpty) {
      b.writeln('بدهی‌ها/طلب‌ها:');
      for (final d in debts.take(5)) {
        b.writeln(
            '  - ${d.personName}: ${PersianFormat.money(d.remainingAmount)} (کل ${PersianFormat.money(d.amount)}، مهلت ${PersianFormat.jalaliLong(d.dueAt)})');
      }
      b.writeln();
    }

    return b.toString();
  }

  String _buildPrompt(String userText, String context) {
    final historyText = _history
        .map((h) => '${h.role == 'user' ? 'کاربر' : 'دستیار'}: ${h.content}')
        .join('\n');

    // ── تعامل دوطرفه: تزریق دانش یادگرفته‌شدهٔ قبلی به پرامپت آنلاین ──
    // تا پاسخ‌های جدید با تجربهٔ قبلی (سبک و محتوا) هماهنگ باشند.
    final learned = memory.similarEntries(userText, limit: 3);
    final learnedText = learned.isEmpty
        ? ''
        : 'دانش یادگرفته‌شدهٔ قبلی (از تعاملات گذشته با هوش آنلاین):\n' +
            learned
                .map((e) => '  سؤال: ${e.question}\n  جواب خوب قبلی: ${e.answer}')
                .join('\n') +
            '\nاگر سؤال کاربر به یکی از موارد بالا نزدیک است، هم‌سبک و هم‌محتوا با آن جواب بده.\n\n';

    return 'تو دستیار برنامه‌ریزی روزانهٔ هوشمند ایرانی هستی. همهٔ پاسخ‌ها فارسی، '
        'کوتاه، دوستانه و عملی باشند. بر اساس داده‌های واقعی زیر از برنامهٔ کاربر جواب بده.\n\n'
        'داده‌های واقعی برنامه:\n$context\n'
        '$learnedText'
        'تاریخچهٔ گفتگو:\n$historyText\n'
        'سؤال کاربر: $userText\n'
        'خروجی: حداکثر ۵ خط فارسی، بدون توضیح اضافه. اگر به داده‌ای نیاز داری که نیست، '
        'بگو «در برنامه ثبت نشده» و راهنمایی کن.';
  }

  String? _extractLocalIntentId(String text) {
    try {
      final rb = ruleBased;
      if (rb is RuleBasedLocalAssistant) {
        final match = rb.detectIntent(text);
        return match?.id;
      }
    } catch (_) {}
    return null;
  }

  /// مانند [_extractLocalIntentId] ولی برای وضوح بیشتر.
  String? _extractLocalIntent(String text) => _extractLocalIntentId(text);

  bool _isRephrase(String a, String b) {
    final na = PersianNormalizer.normalize(a).trim();
    final nb = PersianNormalizer.normalize(b).trim();
    if (na.isEmpty || nb.isEmpty || na == nb) return false;
    final sim = PersianSemanticSimilarity.score(na, nb);
    return sim >= 0.45 && sim < 0.95;
  }

  IntentFeedbackStore get intentFeedback => feedbackStore;

  /// آیا موتور محلی می‌تواند پاسخ معنادار بدهد؟ (نه پاسخ تکراری نامرتبط)
  bool _localCanAnswerMeaningfully(String text) {
    try {
      final dynamic rb = ruleBased;
      if (rb is RuleBasedLocalAssistant) {
        return rb.canAnswerMeaningfully(text);
      }
    } catch (_) {}
    return ruleBased.canHandle(text);
  }

  /// استخراج intent با امتیاز اطمینان (برای تصمیم روتر).
  double? _confidenceOf(String text) {
    final m = _extractLocalIntent(text);
    if (m == null) return null;
    try {
      final dynamic rb = ruleBased;
      final dynamic match = rb.detectIntent(text);
      if (match != null) return (match.confidence as num).toDouble();
    } catch (_) {}
    return null;
  }

  /// دسترسی به روتر محلی/آنلاین (برای تست/دیباگ).
  LocalOnlineRouter get router => onlineRouter;
}
