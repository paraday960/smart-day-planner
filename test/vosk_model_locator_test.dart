import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/voice_input.dart';
import 'package:smart_day_planner/services/vosk_model_locator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vosk_locator_test');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('VoskModelLocator', () {
    test('overridePath موجود → همان مسیر برگردانده می‌شود', () async {
      final zip = File('${tempDir.path}/model.zip');
      await zip.writeAsBytes(List.filled(2 * 1024 * 1024, 0));

      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      expect(await locator.find(overridePath: zip.path), zip.path);
    });

    test('مدل در دایرکتوری اسناد/vosk پیدا می‌شود', () async {
      final dir = Directory('${tempDir.path}/vosk');
      await dir.create(recursive: true);
      final zip = File('${dir.path}/${kVoskModelFileName}');
      await zip.writeAsBytes(List.filled(2 * 1024 * 1024, 0));

      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      expect(await locator.find(), zip.path);
    });

    test('هیچ مدلی نباشد → null', () async {
      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      expect(await locator.find(), isNull);
    });

    test('فایل خیلی کوچک پذیرفته نمی‌شود', () async {
      final fake = File('${tempDir.path}/model.zip');
      await fake.writeAsString('not a model');

      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      expect(await locator.find(overridePath: fake.path), isNull);
    });
  });

  group('VoiceInputFactory (انتخاب موتور)', () {
    test('وقتی آفلاین فعال نباشد → سرویس گوشی (آنلاین)', () async {
      final input = await VoiceInputFactory.create(forceOffline: false);
      expect(input, isA<OnlineVoiceInput>());
    });

    test('وقتی آفلاین فعال و مدل موجود باشد → Vosk', () async {
      final dir = Directory('${tempDir.path}/vosk');
      await dir.create(recursive: true);
      final zip = File('${dir.path}/${kVoskModelFileName}');
      await zip.writeAsBytes(List.filled(2 * 1024 * 1024, 0));

      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      final input = await VoiceInputFactory.create(
        locator: locator,
        forceOffline: true,
      );
      expect(input, isA<OfflineVoskVoiceInput>());
      expect(input.engineName, 'آفلاین (Vosk)');
    });

    test('وقتی آفلاین فعال ولی مدل نباشد → سقوط به سرویس گوشی', () async {
      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      final input = await VoiceInputFactory.create(
        locator: locator,
        forceOffline: true,
      );
      expect(input, isA<OnlineVoiceInput>());
    });

    test('isOfflineAvailable فقط وقتی مدل هم هست true است', () async {
      final locator = VoskModelLocator(
        documentsDirProvider: () async => tempDir,
      );
      expect(
        await VoiceInputFactory.isOfflineAvailable(
          locator: locator,
          forceOffline: true,
        ),
        isFalse,
      );

      final dir = Directory('${tempDir.path}/vosk');
      await dir.create(recursive: true);
      final zip = File('${dir.path}/${kVoskModelFileName}');
      await zip.writeAsBytes(List.filled(2 * 1024 * 1024, 0));

      expect(
        await VoiceInputFactory.isOfflineAvailable(
          locator: VoskModelLocator(
            documentsDirProvider: () async => tempDir,
          ),
          forceOffline: true,
        ),
        isTrue,
      );
    });
  });
}
