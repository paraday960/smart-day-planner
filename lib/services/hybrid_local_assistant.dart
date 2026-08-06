import 'dart:async';

import 'package:flutter/services.dart';

import '../app/feature_flags.dart';
import '../models/task.dart';
import 'local_assistant.dart';
import 'persian_nlu.dart';
import 'smart_planner.dart';

/// خطای مربوط به عدم دسترسی به LLM (باید به fallback برگردد).
class LlmNotAvailableException implements Exception {
  const LlmNotAvailableException([this.message = 'LLM در دسترس نیست']);
  final String message;

  @override
  String toString() => message;
}

/// یک «پشتیبان» (backend) اجرای مدل زبانی محلی.
///
/// پیاده‌سازی واقعی می‌تواند llama.cpp / ONNX / TFLite باشد که از طریق
/// MethodChannel یا پلاگین native در دسترس قرار می‌گیرد. برای تست،
/// [FakeLlmBackend] در test/fakes قرار دارد.
abstract class LlmBackend {
  /// آیا مدل بارگذاری شده و آمادهٔ پاسخ است؟
  Future<bool> get available;

  /// اجرای inference و برگرداندن متن کامل پاسخ.
  /// اگر خطا بدهد، [HybridLocalAssistant] به fallback برمی‌گردد.
  Future<String> generate(String prompt);
}

/// پیاده‌سازی پیش‌فرض: از طریق MethodChannel با سمت native ارتباط می‌گیرد.
///
/// سمت Android/iOS باید channel با نام `ir.smartday.planner/llm` را
/// پیاده‌سازی کند و دو متد داشته باشد:
///   - `isAvailable` → bool
///   - `generate` → { 'prompt': String } → String
///
/// اگر native پیاده‌سازی نشده باشد، `available` به‌درستی false می‌دهد و
/// دستیار روی موتور قانون‌محور می‌ماند (هیچ خطایی به کاربر نمی‌رسد).
class MethodChannelLlmBackend implements LlmBackend {
  MethodChannelLlmBackend();

  static const MethodChannel _channel =
      MethodChannel('ir.smartday.planner/llm');

  bool? _availabilityCache;

  @override
  Future<bool> get available async {
    if (!FeatureFlags.enableLocalLlm) return false;
    if (_availabilityCache != null) return _availabilityCache!;
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      _availabilityCache = ok;
      return ok;
    } on PlatformException {
      _availabilityCache = false;
      return false;
    } on MissingPluginException {
      _availabilityCache = false;
      return false;
    }
  }

  @override
  Future<String> generate(String prompt) async {
    final result =
        await _channel.invokeMethod<String>('generate', {'prompt': prompt});
    if (result == null || result.trim().isEmpty) {
      throw const LlmNotAvailableException('پاسخ خالی از LLM');
    }
    return result;
  }
}

/// دستیار هیبرید: اگر LLM محلی در دسترس باشد از آن استفاده می‌کند،
/// وگرنه به موتور قانون‌محور (rule-based) برمی‌گردد.
///
/// این کلاس با [LlmBackend] تست‌پذیر است؛ در تست‌ها از Fake استفاده می‌کنیم.
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
  String get statusLabel => _enabled && llm != null
      ? 'هوش ترکیبی (LLM + قانونی)'
      : 'هوش قانونی (بدون LLM)';

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
