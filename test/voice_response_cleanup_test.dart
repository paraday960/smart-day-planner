import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/voice_response_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ایموجی‌ها از متن قبل از گفتار حذف می‌شوند', () {
    final service = VoiceResponseService.instance;
    final cleaned = service.prepareForSpeech(
      '🤖 برنامهٔ هوشمند اجرا شد ✨ 😊 قرار با دوست ست شد 📒',
    );
    expect(cleaned.contains('🤖'), isFalse);
    expect(cleaned.contains('✨'), isFalse);
    expect(cleaned.contains('😊'), isFalse);
    expect(cleaned.contains('📒'), isFalse);
    // متن فارسی اصلی باید حفظ شود.
    expect(cleaned.contains('برنامهٔ هوشمند اجرا شد'), isTrue);
  });

  test('متن فارسی بدون ایموجی دست‌نخورده می‌ماند', () {
    final service = VoiceResponseService.instance;
    final cleaned = service.prepareForSpeech('سلام، من دستیار شما هستم');
    expect(cleaned, 'سلام، من دستیار شما هستم');
  });

  test('نمادهای خاص حذف می‌شوند', () {
    final service = VoiceResponseService.instance;
    final cleaned = service.prepareForSpeech('کار «تماس با مشتری» — انجام شد');
    expect(cleaned.contains('«'), isFalse);
    expect(cleaned.contains('»'), isFalse);
    expect(cleaned.contains('—'), isFalse);
  });
}
