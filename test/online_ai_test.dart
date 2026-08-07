import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_day_planner/services/llama_backend.dart';
import 'package:smart_day_planner/services/online_ai_config.dart';
import 'package:smart_day_planner/services/online_llm_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnlineAiConfig', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      OnlineAiConfig.instance.reset();
    });

    test('بدون کلید، hasKey فالس است', () async {
      final cfg = OnlineAiConfig.instance;
      await cfg.load();
      expect(cfg.hasKey, isFalse);
    });

    test('set و clear مقدار کلید را درست تغییر می‌دهد', () async {
      final cfg = OnlineAiConfig.instance;
      await cfg.load();
      await cfg.set('  test-key  ');
      expect(cfg.hasKey, isTrue);
      expect(cfg.apiKey, 'test-key');
      await cfg.clear();
      expect(cfg.hasKey, isFalse);
    });
  });

  group('OnlineLlmBackend', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      OnlineAiConfig.instance.reset();
    });

    test('بدون کلید available فالس است', () async {
      final backend = OnlineLlmBackend(
        config: OnlineAiConfig.instance,
        keyProvider: () => null,
      );
      expect(await backend.available, isFalse);
    });

    test('با کلید از keyProvider available درست است', () async {
      final backend = OnlineLlmBackend(
        config: OnlineAiConfig.instance,
        keyProvider: () => 'gsk_test',
      );
      expect(await backend.available, isTrue);
    });

    test('generate بدون کلید خطای OnlineAiNotAvailable می‌دهد', () async {
      final backend = OnlineLlmBackend(
        config: OnlineAiConfig.instance,
        keyProvider: () => null,
      );
      expect(
        () => backend.generate('سلام'),
        throwsA(isA<OnlineAiNotAvailableException>()),
      );
    });
  });

  group('PriorityLlmBackend', () {
    test('وقتی بک‌اند اول شکست می‌خورد، به دومی برمی‌گردد', () async {
      final first = _FakeBackend(
        availableResult: true,
        onGenerate: () => throw const OnlineAiNotAvailableException('fail'),
      );
      final second = _FakeBackend(
        availableResult: true,
        onGenerate: () async => 'پاسخ از بک‌اند دوم',
      );
      final priority = PriorityLlmBackend([first, second]);
      final result = await priority.generate('سوال');
      expect(result, 'پاسخ از بک‌اند دوم');
    });

    test('وقتی هیچ بک‌اندی available نیست، خطا می‌دهد', () async {
      final first = _FakeBackend(availableResult: false, onGenerate: null);
      final priority = PriorityLlmBackend([first]);
      expect(
        () => priority.generate('سوال'),
        throwsA(isA<OnlineAiNotAvailableException>()),
      );
    });
  });
}

class _FakeBackend implements LlmBackend {
  _FakeBackend({required this.availableResult, this.onGenerate});

  final bool availableResult;
  final Future<String> Function()? onGenerate;

  @override
  Future<bool> get available async => availableResult;

  @override
  Future<String> generate(String prompt) async {
    final fn = onGenerate;
    if (fn == null) {
      throw const OnlineAiNotAvailableException('بدون نتیجه');
    }
    return fn();
  }
}
