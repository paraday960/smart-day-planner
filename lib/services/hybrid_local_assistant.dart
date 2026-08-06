import 'dart:async';


import '../app/feature_flags.dart';
import '../models/task.dart';
import 'local_assistant.dart';
import 'llama_backend.dart';
import 'persian_nlu.dart';
import 'smart_planner.dart';

class HybridLocalAssistant implements LocalLlmAdapter {
  HybridLocalAssistant({
    this.llm,
    LocalLlmAdapter? fallback,
    SmartPlanner? planner,
    Duration timeout = const Duration(seconds: 10),
    bool? enabled,
  })  : _fallback = fallback ??
            RuleBasedLocalAssistant(planner: planner ?? const SmartPlanner()),
        _timeout = timeout,
        _enabled = enabled ?? FeatureFlags.enableLocalLlm;

  /// اگر null باشد، همیشه از fallback استفاده می‌شود.
  final LlmBackend? llm;
  final LocalLlmAdapter _fallback;
  final Duration _timeout;

  /// آیا تلاش برای LLM مجاز است؟ پیش‌فرض از [FeatureFlags.enableLocalLlm]
  /// می‌آید و در تست می‌توان آن را صریحاً تنظیم کرد.
  final bool _enabled;

  /// وضعیت فعلی برای نمایش در UI.
  ///
  /// - اگر LLM فعال و متصل باشد: «هوش ترکیبی (LLM محلی فعال)»
  /// - اگر LLM فعال ولی بدون backend: «هوش قانونی (LLM فعال ولی مدل یافت نشد)»
  /// - در غیر این صورت: «هوش قانونی (بدون LLM)»
  String get statusLabel {
    if (_enabled && llm != null) return 'هوش ترکیبی (LLM محلی فعال)';
    if (_enabled) return 'هوش قانونی (LLM فعال ولی مدل یافت نشد)';
    return 'هوش قانونی (بدون LLM)';
  }

  /// آیا LLM فعال و متصل است؟
  bool get hasLlmConfigured => _enabled && llm != null;

  @override
  Future<String> generate(
      {required String prompt, required List<Task> tasks}) async {
    final backend = llm;
    if (backend != null && _enabled) {
      try {
        final ready = await backend.available;
        if (ready) {
          final llmPrompt = buildLlmPrompt(prompt, tasks);
          return await backend.generate(llmPrompt).timeout(_timeout);
        }
      } on TimeoutException {
        // timeout: به fallback برگرد
      } catch (_) {
        // هر خطای دیگری: به fallback برگرد
      }
    }
    return _fallback.generate(prompt: prompt, tasks: tasks);
  }

  /// ساخت prompt فشرده برای LLM با اطلاعات ضروری کارها.
  static String buildLlmPrompt(String prompt, List<Task> tasks) {
    final normalized = PersianNormalizer.normalize(prompt);
    final lines = <String>[];
    lines.add(
        'تو یک دستیار برنامه‌ریزی روزانهٔ ایرانی هستی. همهٔ پاسخ‌ها فارسی، کوتاه و عملی باشند.');
    lines.add('');
    if (tasks.isEmpty) {
      lines.add('کارهای کاربر: (هیچ کاری ثبت نشده)');
    } else {
      lines.add('کارهای کاربر:');
      for (final task in tasks.take(15)) {
        final status = task.isDone ? 'انجام‌شده' : 'باز';
        final due = task.dueAt != null
            ? '، مهلت: ${task.dueAt!.toIso8601String()}'
            : '';
        lines.add(
            '- ${task.title} (اهمیت ${task.importance}، تخمین ${task.estimatedMinutes} دقیقه، $status$due)');
      }
    }
    lines.add('');
    lines.add('سؤال کاربر: $normalized');
    lines.add('خروجی: حداکثر ۴ خط، فارسی، بدون توضیح اضافه.');
    return lines.join('\n');
  }
}
