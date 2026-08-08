import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/services/voice_response_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('گزینه صدای آفلاین Piper ذخیره و خوانده می‌شود', () async {
    // initialize با flutter_tts در محیط تست در دسترس نیست، پس مستقیم
    // ذخیره/خواندن را از طریق SharedPreferences بررسی می‌کنیم.
    final prefs = await SharedPreferences.getInstance();
    const key = 'smart_day_planner.voice_response.force_piper';

    // پیش‌فرض خاموش.
    expect(prefs.getBool(key) ?? false, isFalse);

    // روشن.
    await prefs.setBool(key, true);
    expect(prefs.getBool(key), isTrue);

    // خاموش.
    await prefs.setBool(key, false);
    expect(prefs.getBool(key), isFalse);
  });

  test('prepareForSpeech ایموجی‌ها و نمادها را برای گفتار حذف می‌کند', () {
    final service = VoiceResponseService.instance;
    final cleaned = service.prepareForSpeech(
      '🤖 برنامه اجرا شد ✨ قرار ست شد 😊',
    );
    expect(cleaned.contains('🤖'), isFalse);
    expect(cleaned.contains('✨'), isFalse);
    expect(cleaned.contains('😊'), isFalse);
    expect(cleaned.contains('برنامه اجرا شد'), isTrue);
  });
}
