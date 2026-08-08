import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/local_smart_summary.dart';

Task _t(String title,
    {int importance = 3,
    EnergyLevel energy = EnergyLevel.medium,
    DateTime? dueAt,
    bool done = false,
    bool pinned = false}) {
  return Task(
    id: title,
    title: title,
    createdAt: DateTime.now(),
    importance: importance,
    energy: energy,
    estimatedMinutes: 30,
    status: done ? TaskStatus.done : TaskStatus.todo,
    dueAt: dueAt,
    isPinned: pinned,
  );
}

void main() {
  group('LocalSmartSummary', () {
    test('وقتی کاری نیست، پیام خالی بودن می‌دهد', () {
      final a = LocalSmartSummary.answer(text: 'چی دارم؟', tasks: const []);
      expect(a, isNotNull);
      expect(a!, contains('نداری'));
    });

    test('کارهای باز را با اولویت‌بندی نشان می‌دهد', () {
      final tasks = [
        _t('کار کم‌اهمیت', importance: 1),
        _t('کار مهم', importance: 5, pinned: true),
        _t('کار معمولی'),
      ];
      final a = LocalSmartSummary.answer(text: 'چی کار کنم؟', tasks: tasks);
      expect(a, isNotNull);
      // کار مهم باید اول باشد
      final idxImportant = a!.indexOf('کار مهم');
      final idxLow = a.indexOf('کار کم‌اهمیت');
      expect(idxImportant, lessThan(idxLow));
      expect(a.contains('🎯') || a.contains('🥈') || a.contains('🥉'), isTrue);
    });

    test('کارهای عقب‌افتاده را هشدار می‌دهد', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final tasks = [_t('کار عقب‌افتاده', dueAt: past)];
      final a = LocalSmartSummary.answer(text: 'چی کار کنم؟', tasks: tasks);
      expect(a, contains('تأخیر'));
    });

    test('سؤال زمانی، نزدیک‌ترین مهلت را می‌گوید', () {
      final soon = DateTime.now().add(const Duration(hours: 3));
      final far = DateTime.now().add(const Duration(days: 5));
      final tasks = [
        _t('کار دوردست', dueAt: far),
        _t('کار نزدیک', dueAt: soon),
      ];
      final a = LocalSmartSummary.answer(text: 'کی چی دارم؟', tasks: tasks);
      expect(a, contains('کار نزدیک'));
      expect(a, contains('ساعت دیگر'));
    });

    test('سؤال مالی را به لایهٔ بعدی می‌سپارد (null)', () {
      final a = LocalSmartSummary.answer(text: 'چقدر پول دارم؟', tasks: const []);
      expect(a, isNull);
    });

    test('خلاصهٔ وضعیت برای پرسش کوتاه ناشناخته', () {
      final tasks = [_t('یک کار'), _t('دو کار', done: true)];
      final a = LocalSmartSummary.answer(text: 'چی؟', tasks: tasks);
      expect(a, isNotNull);
      expect(a, contains('کار باز'));
    });

    test('تعداد کل دقیقه‌ها را گزارش می‌دهد', () {
      final tasks = [_t('الف'), _t('ب')];
      final a = LocalSmartSummary.answer(text: 'برنامه چیه؟', tasks: tasks);
      final text = a ?? '';
      final ok = text.contains('۶۰') || text.contains('1 ساعت') || text.contains('۶۰ دقیقه');
      expect(ok, isTrue, reason: 'باید ۶۰ دقیقه یا ۱ ساعت را نشان دهد: $text');
    });
  });
}
