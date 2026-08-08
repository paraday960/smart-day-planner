import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/app/feature_flags.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/hybrid_local_assistant.dart';
import 'package:smart_day_planner/services/llama_backend.dart';
import 'package:smart_day_planner/services/local_assistant.dart';

import 'fakes/fake_platform_services.dart';

Task _task(String id, String title) => Task(
      id: id,
      title: title,
      createdAt: DateTime.now(),
      importance: 3,
      estimatedMinutes: 30,
    );

void main() {
  test('LLM در دسترس → پاسخ از LLM می‌آید و fallback صدا زده نمی‌شود',
      () async {
    final backend = FakeLlmBackend(response: 'پاسخ LLM');
    var fallbackCalled = false;
    final hybrid = HybridLocalAssistant(
      llm: backend,
      enabled: true,
      fallback: _RecordingFallback(() => fallbackCalled = true),
    );

    final answer =
        await hybrid.generate(prompt: 'سلام', tasks: [_task('1', 'کار')]);

    expect(answer, 'پاسخ LLM');
    expect(backend.callCount, 1);
    expect(backend.prompts.single, contains('سلام'));
    expect(fallbackCalled, isFalse);
  });

  test('LLM خطا بدهد → fallback پاسخ می‌دهد', () async {
    final backend =
        FakeLlmBackend(failWith: const LlmNotAvailableException('crash'));
    final hybrid = HybridLocalAssistant(
      llm: backend,
      enabled: true,
      fallback: RuleBasedLocalAssistant(),
    );

    final answer = await hybrid.generate(
        prompt: 'الان چی کار کنم؟', tasks: [_task('1', 'تماس با مشتری')]);

    expect(answer, contains('تماس با مشتری'));
    expect(backend.callCount, 1);
  });

  test('LLM در دسترس نباشد → fallback پاسخ می‌دهد', () async {
    final backend = FakeLlmBackend(isReady: false);
    final hybrid = HybridLocalAssistant(
      llm: backend,
      fallback: RuleBasedLocalAssistant(),
    );

    final answer = await hybrid.generate(prompt: 'سلام', tasks: const []);

    expect(answer, contains('سلام'));
    expect(backend.callCount, 0);
  });

  test('llm == null → مستقیماً fallback', () async {
    final hybrid = HybridLocalAssistant(fallback: RuleBasedLocalAssistant());
    final answer = await hybrid.generate(prompt: 'سلام', tasks: const []);
    expect(answer, contains('سلام'));
  });

  test('buildLlmPrompt: شامل کارها و دستور فارسی است', () {
    final prompt = HybridLocalAssistant.buildLlmPrompt(
      'الان چی کار کنم؟',
      [_task('1', 'تماس با مشتری')],
    );
    expect(prompt, contains('تماس با مشتری'));
    expect(prompt, contains('فارسی'));
    expect(prompt, contains('الان چی کار کنم'));
  });

  test('feature flag پیش‌فرض روشن است؛ بدون backend واقعی، fallback قانونی می‌ماند', () {
    expect(FeatureFlags.enableLocalLlm, isTrue);
    final hybrid = HybridLocalAssistant(
        llm: null, fallback: RuleBasedLocalAssistant());
    expect(hybrid.hasLlmConfigured, isFalse);
    expect(hybrid.statusLabel, contains('قانونی'));
  });
}

/// Fallback ثبت‌کنندهٔ صدا زدن (برای بررسی اینکه صدا زده نشده).
class _RecordingFallback implements LocalLlmAdapter {
  _RecordingFallback(this._onCalled);

  final void Function() _onCalled;

  @override
  bool canHandle(String prompt) => true;

  @override
  Future<String> generate(
      {required String prompt, required List<Task> tasks}) async {
    _onCalled();
    return 'fallback';
  }
}
