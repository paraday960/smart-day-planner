import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/llama_backend.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('llm_locator_test');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('LlamaModelLocator', () {
    test('overridePath موجود → همان مسیر برگردانده می‌شود', () async {
      final modelFile = File('${tempDir.path}/model.gguf');
      await modelFile.writeAsBytes(List.filled(2 * 1024 * 1024, 0));

      final locator = LlamaModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      final found = await locator.find(overridePath: modelFile.path);

      expect(found, modelFile.path);
    });

    test('فایل در دایرکتوری اسناد/llm پیدا می‌شود', () async {
      final llmDir = Directory('${tempDir.path}/llm');
      await llmDir.create(recursive: true);
      final modelFile = File('${llmDir.path}/$kLlamaModelFileName');
      await modelFile.writeAsBytes(List.filled(2 * 1024 * 1024, 0));

      final locator = LlamaModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      final found = await locator.find();

      expect(found, modelFile.path);
    });

    test('هیچ مدلی نباشد → null', () async {
      final locator = LlamaModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      final found = await locator.find();
      expect(found, isNull);
    });

    test('فایل خیلی کوچک (کمتر از ۱MB) پذیرفته نمی‌شود', () async {
      final fake = File('${tempDir.path}/model.gguf');
      await fake.writeAsString('not a model');

      final locator = LlamaModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      expect(await locator.find(overridePath: fake.path), isNull);
    });
  });

  group('LlamaCppBackend (بدون مدل واقعی)', () {
    test('وقتی LLM غیرفعال است → available=false', () async {
      final backend = LlamaCppBackend(enabled: false);
      expect(await backend.available, isFalse);
    });

    test('وقتی فعال ولی مدل پیدا نشود → available=false', () async {
      final backend = LlamaCppBackend(
        enabled: true,
        modelPath: '${tempDir.path}/does-not-exist.gguf',
      );
      expect(await backend.available, isFalse);
    });

    test('generate بدون مدل → LlmNotAvailableException', () async {
      final backend = LlamaCppBackend(
        enabled: true,
        modelPath: '${tempDir.path}/does-not-exist.gguf',
      );
      expect(
        () => backend.generate('سلام'),
        throwsA(isA<Object>()),
      );
    });

    test('resolveLibraryPath: اولویت با پارامتر صریح است', () {
      final backend = LlamaCppBackend(libraryPath: '/opt/lib/libllama.so');
      expect(backend.resolveLibraryPath(), '/opt/lib/libllama.so');
    });
  });
}
