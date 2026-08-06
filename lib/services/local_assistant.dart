import '../models/task.dart';
import '../utils/persian_format.dart';
import 'smart_planner.dart';

/// قرارداد اتصال LLM آفلاین واقعی.
/// بعداً می‌توانی این را با llama.cpp / ONNX / TFLite پیاده‌سازی کنی.
abstract class LocalLlmAdapter {
  Future<String> generate({
    required String prompt,
    required List<Task> tasks,
  });
}

/// نسخه فعلی کاملاً آفلاین و رایگان است؛ به جای LLM سنگین، از منطق قابل توضیح استفاده می‌کند.
class RuleBasedLocalAssistant implements LocalLlmAdapter {
  RuleBasedLocalAssistant({SmartPlanner planner = const SmartPlanner()}) : _planner = planner;

  final SmartPlanner _planner;

  @override
  Future<String> generate({required String prompt, required List<Task> tasks}) async {
    final normalized = prompt.trim();
    final open = tasks.where((t) => !t.isDone).toList();

    if (normalized.isEmpty) {
      return _dailyBrief(tasks);
    }

    if (_containsAny(normalized, ['بعدی', 'الان', 'شروع', 'اول'])) {
      if (open.isEmpty) return 'همه کارها انجام شده‌اند. کار جدیدی ثبت کن یا کمی استراحت کن.';
      final sorted = [...open]
        ..sort((a, b) => _planner.priorityScore(b).compareTo(_planner.priorityScore(a)));
      final top = sorted.first;
      return 'پیشنهاد من اینه الان «${top.title}» رو شروع کنی. دلیل: ${_planner.explainPriority(top)}. زمان پیشنهادی: ${PersianFormat.minutes(_planner.recommendedEstimate(top, tasks))}.';
    }

    if (_containsAny(normalized, ['برنامه', 'امروز', 'زمان‌بندی'])) {
      final plan = _planner.buildTodayPlan(tasks);
      if (plan.isEmpty) return 'برای امروز برنامه قابل چیدن ندارم؛ یا زمان روز تمام شده یا کاری ثبت نشده.';
      return plan
          .take(6)
          .map((item) => '${PersianFormat.time(item.start)} تا ${PersianFormat.time(item.end)} — ${item.task.title}')
          .join('\n');
    }

    if (_containsAny(normalized, ['مشکل', 'عقب', 'ریسک', 'دیر'])) {
      final overdue = open.where((t) => t.isOverdue).toList();
      if (overdue.isEmpty) return 'فعلاً کار عقب‌افتاده جدی نمی‌بینم. مراقب کارهای با مهلت انجام نزدیک باش.';
      return 'این کارها ریسک بیشتری دارند:\n${overdue.map((t) => '• ${t.title}').join('\n')}';
    }

    return _dailyBrief(tasks);
  }

  String _dailyBrief(List<Task> tasks) {
    final suggestions = _planner.suggestions(tasks);
    final openCount = tasks.where((t) => !t.isDone).length;
    final doneCount = tasks.where((t) => t.isDone).length;
    return 'خلاصه امروز: ${PersianFormat.digits(openCount)} کار باز و ${PersianFormat.digits(doneCount)} کار انجام‌شده داری.\n${suggestions.map((s) => '• $s').join('\n')}';
  }

  bool _containsAny(String text, List<String> words) => words.any(text.contains);
}
