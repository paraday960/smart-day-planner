import 'dart:async';

import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';
import 'debt_repository.dart';
import 'llama_backend.dart';
import 'local_assistant.dart';
import 'local_assistant_memory.dart';

/// یک پیام در تاریخچهٔ مکالمه.
class ChatTurn {
  ChatTurn({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;
}

/// دستیار گفتگوی هوشمند.
///
/// تفاوت با دستیار قبلی:
/// 1. **دادهٔ واقعی برنامه** را به هوش آنلاین می‌دهد (مالی، کارها، بدهی‌ها،
///    اهداف) تا پاسخ‌ها بر اساس وضعیت واقعی کاربر باشد، نه عمومی.
/// 2. **حافظهٔ مکالمه** دارد (چند مرحلهٔ پیوسته).
/// 3. **مسیریابی هوشمند**: تشخیص می‌دهد سناریو، فرمان اجرایی یا سؤال عادی است.
class IntelligentAssistantService {
  IntelligentAssistantService({
    required this.online,
    required this.ruleBased,
    required this.finance,
    required this.goal,
    required this.debt,
    LocalAssistantMemory? memory,
    this.maxHistoryTurns = 8,
    Duration timeout = const Duration(seconds: 40),
  })  : _timeout = timeout,
        memory = memory ?? LocalAssistantMemory.instance;

  final LlmBackend? online;
  final LocalLlmAdapter ruleBased;
  final FinanceRepository finance;
  final GoalRepository goal;
  final DebtRepository debt;
  final Duration _timeout;
  final int maxHistoryTurns;

  /// حافظهٔ یادگیری محلی (سؤال → جواب).
  final LocalAssistantMemory memory;

  /// تاریخچهٔ مکالمه (محدود به [maxHistoryTurns]).
  final List<ChatTurn> _history = [];

  /// پاسخ به یک درخواست کاربر (با حافظهٔ مکالمه + یادگیری محلی).
  Future<String> ask({
    required String userText,
    required List<Task> tasks,
  }) async {
    final t = userText.trim();
    if (t.isEmpty) return 'چیزی نشنیدم. بگو چطور می‌توانم کمکت کنم.';

    await memory.load();

    _history.add(ChatTurn(role: 'user', content: t));
    // محدود کردن تاریخچه
    if (_history.length > maxHistoryTurns) {
      _history.removeRange(0, _history.length - maxHistoryTurns);
    }

    String answer;
    final fromMemory = memory.lookup(t);
    if (fromMemory != null) {
      // دستیار این سؤال را «یاد گرفته» — مستقیم از محلی جواب بده.
      answer = fromMemory;
    } else {
      // آیا هوش محلی (قانون‌محور) این سؤال را می‌فهمد؟
      final localCanHandle = ruleBased.canHandle(t);
      final onlineAvailable = await _isOnlineAvailable();

      if (localCanHandle) {
        // محلی بلد است → سریع و رایگان از محلی جواب بده.
        answer = await ruleBased.generate(prompt: t, tasks: tasks);
      } else if (onlineAvailable) {
        // محلی متوجه نشد → از آنلاین بپرس و یاد بگیر.
        answer = await _askOnline(t, tasks);
        await memory.remember(t, answer);
      } else {
        // آنلاین هم در دسترس نیست → محلی (به‌ترین تلاش).
        answer = await ruleBased.generate(prompt: t, tasks: tasks);
      }
    }

    _history.add(ChatTurn(role: 'assistant', content: answer));
    return answer;
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

  /// پرسش از هوش آنلاین با context کامل برنامه.
  Future<String> _askOnline(String userText, List<Task> tasks) async {
    final context = _buildContext(tasks);
    final prompt = _buildPrompt(userText, context);
    try {
      return await online!
          .generate(prompt)
          .timeout(_timeout, onTimeout: () => _ruleBasedAnswer(userText, tasks));
    } catch (_) {
      return _ruleBasedAnswer(userText, tasks);
    }
  }

  String _ruleBasedAnswer(String text, List<Task> tasks) {
    try {
      return ruleBased.generate(prompt: text, tasks: tasks).toString();
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
    return 'تو دستیار برنامه‌ریزی روزانهٔ هوشمند ایرانی هستی. همهٔ پاسخ‌ها فارسی، '
        'کوتاه، دوستانه و عملی باشند. بر اساس داده‌های واقعی زیر از برنامهٔ کاربر جواب بده.\n\n'
        'داده‌های واقعی برنامه:\n$context\n'
        'تاریخچهٔ گفتگو:\n$historyText\n'
        'سؤال کاربر: $userText\n'
        'خروجی: حداکثر ۵ خط فارسی، بدون توضیح اضافه. اگر به داده‌ای نیاز داری که نیست، '
        'بگو «در برنامه ثبت نشده» و راهنمایی کن.';
  }
}
