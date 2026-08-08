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
  bool canHandle(String prompt) => _fallback.canHandle(prompt);

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
  /// ارتقای سطح ۱: پرامپت حالا تاریخ شمسی امروز + خلاصه کارها + دستور دقیق‌تر دارد
  static String buildLlmPrompt(String prompt, List<Task> tasks) {
    final normalized = PersianNormalizer.normalize(prompt);
    final now = DateTime.now();
    final jalali = '${now.year}/${now.month}/${now.day}';
    final lines = <String>[];
    lines.add(
        'تو دستیار هوشمند آفلاین ایرانی هستی (هوش محلی). همه پاسخ‌ها فارسی، صمیمی، کوتاه (حداکثر ۴ خط) و عملی باشند. اگر اطلاعات کافی نداری، بگو «در برنامه ثبت نشده».');
    lines.add('تاریخ امروز: $jalali');
    lines.add('');
    if (tasks.isEmpty) {
      lines.add('کارهای کاربر: (هیچ کاری ثبت نشده — پیشنهاد بده کار جدید بسازد)');
    } else {
      final open = tasks.where((t) => !t.isDone).length;
      final done = tasks.where((t) => t.isDone).length;
      lines.add('خلاصه: $open کار باز، $done انجام‌شده');
      lines.add('کارهای باز:');
      for (final task in tasks.where((t) => !t.isDone).take(12)) {
        final status = task.isDone ? 'انجام‌شده' : 'باز';
        final due = task.dueAt != null ? '، مهلت: ${task.dueAt!.toIso8601String()}' : '، بدون مهلت';
        final prio = task.importance >= 4 ? ' (مهم)' : '';
        lines.add('- ${task.title}$prio (اهمیت ${task.importance}، ${task.estimatedMinutes} دقیقه، $status$due)');
      }
      if (open > 12) lines.add('... و ${open - 12} کار دیگر');
    }
    lines.add('');
    lines.add('دستور: با توجه به کارهای بالا، به سؤال کاربر دقیق و کاربردی جواب بده. اگر سؤال درباره بدهی/مالی بود و داده‌ای نیست، بگو «بدهی ثبت نشده».');
    lines.add('سؤال کاربر: $normalized');
    lines.add('خروجی: فقط فارسی، بدون انگلیسی، بدون توضیح اضافه.');
    return lines.join('\n');
  }
}
