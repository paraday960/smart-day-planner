import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/app/feature_flags.dart';

void main() {
  test('feature flags expose default release configuration', () {
    final flags = FeatureFlags.asMap();

    expect(flags.containsKey('voiceInput'), isTrue);
    expect(flags.containsKey('voiceResponse'), isTrue);
    expect(flags.containsKey('calendar'), isTrue);
    expect(flags.containsKey('pdfExport'), isTrue);
    expect(flags.containsKey('shareFiles'), isTrue);
    expect(flags.containsKey('smartNotifications'), isTrue);
    expect(flags.containsKey('encryptedBackup'), isTrue);
    expect(flags.containsKey('localLlm'), isTrue);
    expect(FeatureFlags.hasRiskyPlatformFeatureEnabled, isTrue);
  });

  test('default release keeps every feature enabled', () {
    // نسخه انتشار پیش‌فرض باید همه قابلیت‌ها را روشن نگه دارد؛
    // خاموش‌کردن فقط با --dart-define در بیلد امن/دیباگ انجام می‌شود.
    expect(FeatureFlags.enableVoiceInput, isTrue);
    expect(FeatureFlags.enableVoiceResponse, isTrue);
    expect(FeatureFlags.enableCalendar, isTrue);
    expect(FeatureFlags.enablePdfExport, isTrue);
    expect(FeatureFlags.enableShareFiles, isTrue);
    expect(FeatureFlags.enableSmartNotifications, isTrue);
    expect(FeatureFlags.enableEncryptedBackup, isTrue);
    // LLM محلی پیش‌فرض خاموش است (مدل سنگین است و باید جدا اضافه شود)
    expect(FeatureFlags.enableLocalLlm, isFalse);
  });

  test('flag map values match the constants', () {
    final flags = FeatureFlags.asMap();
    expect(flags['voiceInput'], FeatureFlags.enableVoiceInput);
    expect(flags['voiceResponse'], FeatureFlags.enableVoiceResponse);
    expect(flags['calendar'], FeatureFlags.enableCalendar);
    expect(flags['pdfExport'], FeatureFlags.enablePdfExport);
    expect(flags['shareFiles'], FeatureFlags.enableShareFiles);
    expect(flags['smartNotifications'], FeatureFlags.enableSmartNotifications);
    expect(flags['encryptedBackup'], FeatureFlags.enableEncryptedBackup);
    expect(flags['localLlm'], FeatureFlags.enableLocalLlm);
  });
}
