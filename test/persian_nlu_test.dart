import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/persian_nlu.dart';

void main() {
  group('PersianNormalizer', () {
    test('یکسان‌سازی حروف عربی به فارسی', () {
      expect(PersianNormalizer.normalize('كيف'), 'کیف');
      expect(PersianNormalizer.normalize('ميثم'), 'میثم');
      expect(PersianNormalizer.normalize('اي'), 'ای');
      expect(PersianNormalizer.normalize('احمد'), 'احمد');
      expect(PersianNormalizer.normalize('عليه'), 'علیه');
    });

    test('تبدیل اعداد فارسی و عربی به لاتین', () {
      expect(PersianNormalizer.normalize('۱۲۳'), '123');
      expect(PersianNormalizer.normalize('٤٥٦'), '456');
      expect(PersianNormalizer.normalize('۰۹'), '09');
    });

    test('حذف اعراب و کشیدگی', () {
      expect(PersianNormalizer.normalize('بِه'), 'به');
      expect(PersianNormalizer.normalize('خوبـــ'), 'خوب');
    });

    test('جمع کردن فاصله‌های تکراری', () {
      expect(PersianNormalizer.normalize('سلام    دنیا'), 'سلام دنیا');
    });

    test('حذف ZWNJ در نسخهٔ سست و حفظ در نسخهٔ کامل', () {
      expect(PersianNormalizer.normalize('می‌خواهم'), 'می‌خواهم');
      expect(
          PersianNormalizer.normalize('می‌خواهم', keepZwnj: false), 'میخواهم');
      expect(PersianNormalizer.loose('می‌خواهم'), 'میخواهم');
    });
  });

  group('PersianMatcher', () {
    test('تطبیق با وجود نیم‌فاصله یا فاصله', () {
      expect(PersianMatcher.hasAny('برنامه امروزم را بچین', ['برنامه امروز']),
          isTrue);
      expect(
          PersianMatcher.hasAny('برنامه‌ی امروز', ['برنامه امروز']), isFalse);
    });

    test('تطبیق با وجود حروف عربی', () {
      expect(PersianMatcher.hasAny('كار بعدي چيه', ['کار بعدی']), isTrue);
    });

    test('تطبیق کلمهٔ سست بدون فاصله', () {
      expect(PersianMatcher.hasAny('من ریسک مالی دارم', ['ریسک']), isTrue);
      expect(PersianMatcher.hasAny('درآمد چقدره', ['درآمد']), isTrue);
    });

    test('countMatches تعداد الگوهای تطبیق‌یافته را می‌شمارد', () {
      expect(
          PersianMatcher.countMatches(
              'ریسک و برنامه امروز', ['ریسک', 'برنامه امروز']),
          2);
      expect(PersianMatcher.countMatches('سلام', ['ریسک', 'برنامه']), 0);
    });
  });

  group('IntentDetector', () {
    const intents = [
      NluIntent(id: 'greeting', patterns: ['سلام', 'درود']),
      NluIntent(
          id: 'plan',
          patterns: ['برنامه امروز', 'امروز چی کار کنم'],
          priority: 5),
      NluIntent(id: 'risk', patterns: ['ریسک', 'مشکل'], priority: 10),
    ];

    const detector = IntentDetector(intents: intents);

    test('تشخیص سادهٔ قصد', () {
      expect(detector.detect('سلام!')?.id, 'greeting');
      expect(detector.detect('برنامه امروزمو بچین')?.id, 'plan');
      expect(detector.detect('ریسک مالی دارم؟')?.id, 'risk');
    });

    test('نرمال‌سازی روی ورودی اعمال می‌شود', () {
      expect(detector.detect('برنامه امروزمو بچين')?.id, 'plan');
    });

    test('متن خالی یا نامربوط null می‌دهد', () {
      expect(detector.detect(''), isNull);
      expect(detector.detect('سینما رفتن'), isNull);
    });

    test('اولویت در تساوی امتیاز', () {
      // «مشکل» با «ریسک» در یک جمله: هر دو منطبق‌اند؛ اولویت risk بالاتر است
      expect(detector.detect('ریسک مشکل')?.id, 'risk');
    });
  });
}
