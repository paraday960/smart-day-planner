import '../models/task.dart';
import '../models/finance_transaction.dart';
import '../models/debt_item.dart';
import '../utils/persian_format.dart';
import 'advanced_habit_learning_service.dart';
import 'allocation_repository.dart';
import 'command_confidence_service.dart';
import 'conversation_memory_service.dart';
import 'debt_repository.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';
import 'planned_expense_repository.dart';
import 'task_repository.dart';
import 'voice_command_processor.dart';

/// حالت کار دستیار خودکار
enum AutonomousMode {
  /// خاموش - کاربر همه چیز را دستی انجام می‌دهد (رفتار فعلی)
  off,
  /// هیبرید هوشمند - دستیار همه را خودکار انجام می‌دهد، فقط موارد حساس/مبهم تایید می‌خواهد
  hybrid,
  /// تمام خودکار - دستیار بدون تایید همه چیز را اجرا می‌کند (فقط برای تست)
  fullAuto,
}

class AutonomousResult {
  const AutonomousResult({
    required this.executed,
    required this.message,
    required this.needsConfirmation,
    this.pendingAction,
  });

  final bool executed;
  final String message;
  final bool needsConfirmation;
  /// عملی که منتظر تایید است (برای ادامه مکالمه)
  final String? pendingAction;
}

/// سرویس دستیار خودکار هیبرید — تمام کارها توسط دستیار
/// کاربر فقط فرمان صوتی/متنی می‌دهد، دستیار بقیه را انجام می‌دهد
class AutonomousAgentService {
  const AutonomousAgentService({
    this.mode = AutonomousMode.hybrid,
    this.confidenceService = const CommandConfidenceService(),
  });

  final AutonomousMode mode;
  final CommandConfidenceService confidenceService;

  bool get isEnabled => mode != AutonomousMode.off;
  bool get isHybrid => mode == AutonomousMode.hybrid;

  /// آیا این عملیات نیاز به تایید دارد؟
  bool needsConfirmation({
    required String intent,
    required int amount,
    required double confidenceScore,
  }) {
    if (mode == AutonomousMode.fullAuto) return false;
    if (mode == AutonomousMode.off) return true;
    // hybrid: فقط اگر confidence پایین یا مبلغ حساس
    if (confidenceScore < 0.75) return true;
    if (amount >= 1000000) return true; // بالای ۱ میلیون
    if (intent == 'debt_payment' && amount >= 500000) return true;
    return false;
  }

  /// اجرای خودکار یک دستور از روی متن — بدون نیاز به UI دستی کاربر
  /// این متد تمام repositoryها را مستقیم صدا می‌زند
  ///
  /// **اصلاح 2026-08-07:** همهٔ repoها required شدند تا پیام «هنوز وصل نشده»
  /// حذف شود و از crash با `!` جلوگیری شود.
  Future<AutonomousResult> handleAutonomously({
    required String rawText,
    required TaskRepository taskRepository,
    required FinanceRepository financeRepository,
    required GoalRepository goalRepository,
    required DebtRepository debtRepository,
    required PlannedExpenseRepository plannedExpenseRepository,
    required AllocationRepository allocationRepository,
    ConversationMemoryService? conversationMemory,
  }) async {
    if (!isEnabled) {
      return const AutonomousResult(
        executed: false,
        message: 'حالت خودکار خاموش است. از تنظیمات آن را روشن کن.',
        needsConfirmation: false,
      );
    }

    final processor = VoiceCommandProcessor(
      taskRepository: taskRepository,
      financeRepository: financeRepository,
      goalRepository: goalRepository,
      debtRepository: debtRepository,
      plannedExpenseRepository: plannedExpenseRepository,
      allocationRepository: allocationRepository,
      conversationMemory: conversationMemory,
    );

    final normalized = rawText.trim();
    if (normalized.isEmpty) {
      return const AutonomousResult(
        executed: false,
        message: 'فرمانی دریافت نشد.',
        needsConfirmation: false,
      );
    }

    // اگر مکالمه ناتمام وجود دارد، ادامه بده
    if (conversationMemory?.hasPending == true) {
      final reply = await processor.handle(rawText);
      // در حالت هیبرید، جواب processor کافی است
      return AutonomousResult(
        executed: false,
        message: reply,
        needsConfirmation: false,
      );
    }

    // تشخیص خودکار نوع دستور و confidence
    final intent = _detectIntent(normalized);
    final amount = _extractAmount(normalized);
    final confidence = _estimateConfidence(normalized, intent, amount);

    // اگر هیبرید و confidence پایین → تایید بخواه
    if (isHybrid && needsConfirmation(intent: intent, amount: amount, confidenceScore: confidence)) {
      final reply = await processor.handle(rawText);
      // اگر processor تایید خواست، همان را برگردان
      if (reply.contains('تایید') || reply.contains('مطمئنی') || reply.contains('آیا')) {
        return AutonomousResult(
          executed: false,
          message: '🤖 دستیار خودکار: $reply\n\nبگو "تایید" تا اجرا کنم یا "لغو" برای انصراف.',
          needsConfirmation: true,
          pendingAction: rawText,
        );
      }
      // حتی اگر processor مستقیم اجرا کرد، ما هم پیام تایید هوشمند اضافه می‌کنیم
      return AutonomousResult(
        executed: true,
        message: reply,
        needsConfirmation: false,
      );
    }

    // اجرای مستقیم
    try {
      final reply = await processor.handle(rawText);
      return AutonomousResult(
        executed: true,
        message: '🤖 خودکار انجام شد:\n$reply',
        needsConfirmation: false,
      );
    } catch (e) {
      return AutonomousResult(
        executed: false,
        message: 'خطا در اجرای خودکار: $e',
        needsConfirmation: false,
      );
    }
  }

  /// برنامه‌ریزی خودکار روزانه — هر روز صبح اجرا می‌شود
  String autoPlanDay({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
  }) {
    final adv = const AdvancedHabitLearningService();
    final profile = adv.analyze(tasks: tasks, transactions: transactions);
    final suggestions = adv.suggestions(profile);

    final open = tasks.where((t) => !t.isDone).length;
    if (open == 0) return 'امروز کاری نداری — استراحت کن یا کار جدید بساز!';

    final buf = StringBuffer()..writeln('🤖 برنامه خودکار امروز:');
    buf.writeln('• ${PersianFormat.digits(open)} کار باز داری');
    if (profile.streakDays > 0) buf.writeln('• استریک: ${PersianFormat.digits(profile.streakDays)} روز 🔥');
    for (final s in suggestions.take(3)) {
      buf.writeln('• $s');
    }
    return buf.toString();
  }

  /// تخصیص خودکار درآمد جدید به بدهی‌ها و هزینه‌ها
  List<String> autoAllocateIncome({
    required int newIncome,
    required List<DebtItem> debts,
    required List allocations,
  }) {
    if (newIncome <= 0) return ['مبلغی برای تخصیص نیست'];
    // منطق ساده: اول بدهی‌های فوری، بعد هزینه‌های نزدیک
    final sortedDebts = [...debts]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final result = <String>[];
    var remaining = newIncome;
    for (final d in sortedDebts.take(3)) {
      if (remaining <= 0) break;
      final need = d.remainingAmount;
      if (need <= 0) continue;
      final alloc = remaining >= need ? need : (remaining * 0.6).round();
      result.add('برای بدهی ${d.personName}: ${PersianFormat.money(alloc)}');
      remaining -= alloc;
    }
    if (remaining > 0) {
      result.add('باقی‌مانده آزاد: ${PersianFormat.money(remaining)}');
    }
    return result;
  }

  String _detectIntent(String text) {
    final t = text.toLowerCase();
    if (t.contains('بدهی') || t.contains('بدهکار') || t.contains('قرض') || t.contains('وام')) return 'debt';
    if (t.contains('پرداخت') || t.contains('پس دادم')) return 'debt_payment';
    if (t.contains('کنار بذار') || t.contains('کنار بگذار')) return 'allocation';
    if (t.contains('کار') || t.contains('وظیفه') || t.contains('قرار') || t.contains('جلسه')) return 'task';
    if (t.contains('هزینه') || t.contains('خرج')) return 'expense';
    return 'general';
  }

  int _extractAmount(String text) {
    // استخراج ساده عدد + هزار/میلیون/میل/میلیارد
    final normalized = PersianFormat.englishDigits(text);
    final reg = RegExp(r'(\d+)\s*(میلیارد|میلیون|میل|هزار|تومان|تومن)?');
    final match = reg.firstMatch(normalized);
    if (match == null) return 0;
    var value = int.tryParse(match.group(1) ?? '0') ?? 0;
    final unit = match.group(2) ?? '';
    if (unit.contains('میلیارد')) value *= 1000000000;
    else if (unit.contains('میلیون') || unit == 'میل' || unit.contains('میل')) value *= 1000000;
    else if (unit.contains('هزار')) value *= 1000;
    return value;
  }

  double _estimateConfidence(String text, String intent, int amount) {
    var score = 0.5;
    if (amount > 0) score += 0.2;
    if (text.contains('تومان') || text.contains('هزار') || text.contains('میلیون') || text.contains('میل') || text.contains('میلیارد')) score += 0.15;
    if (text.contains('پونصد') || text.contains('پانصد')) score -= 0.15;
    if (intent != 'general') score += 0.15;
    return score.clamp(0.0, 1.0);
  }
}
