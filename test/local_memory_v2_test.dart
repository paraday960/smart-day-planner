import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_day_planner/services/local_assistant_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAssistantMemory mem;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mem = LocalAssistantMemory(maxEntries: 6, storageKey: 'test_mem_v2');
  });

  test('rememberEntry متادیتا را ذخیره و lookup برمی‌گرداند', () async {
    await mem.rememberEntry(
      'بدهی فرهاد چقدره؟',
      '۲ میلیون',
      source: MemorySource.online,
    );
    expect(mem.count, 1);
    expect(mem.lookup('بدهی فرهاد چقدره؟'), '۲ میلیون');

    final e = mem.lookupEntry('بدهی فرهاد چقدره؟');
    expect(e, isNotNull);
    expect(e!.source, MemorySource.online);
    expect(e.useCount, 0);
    expect(e.feedbackScore, 0);
    expect(e.answer, '۲ میلیون');
  });

  test('recordHit شمارنده استفاده و زمان آخرین استفاده را بالا می‌برد', () async {
    await mem.rememberEntry('سوال', 'جواب');
    await mem.recordHit('سوال');
    await mem.recordHit('سوال');
    final e = mem.lookupEntry('سوال');
    expect(e!.useCount, 2);
  });

  test('بازخورد منفی مکرر باعث حذف ورودی (خودپاک‌سازی) می‌شود', () async {
    await mem.rememberEntry('سوال', 'جواب');

    // بازخورد منفی اول: امتیاز -۰.۴ → ورودی می‌ماند
    final afterFirst = await mem.rate('سوال', positive: false);
    expect(afterFirst, isNotNull);
    expect(afterFirst!.feedbackScore, closeTo(-0.4, 0.001));

    // بازخورد منفی دوم: امتیاز -۰.۸ → ورودی حذف می‌شود
    final afterSecond = await mem.rate('سوال', positive: false);
    expect(afterSecond, isNull);
    expect(mem.lookup('سوال'), isNull);
    expect(mem.count, 0);
  });

  test('بازخورد مثبت امتیاز ورودی را بالا می‌برد', () async {
    await mem.rememberEntry('سوال', 'جواب');
    final after = await mem.rate('سوال', positive: true);
    expect(after!.feedbackScore, closeTo(0.3, 0.001));
    expect(after.degraded, isFalse);
  });

  test('مهاجرت خودکار از نسخهٔ ۱ (نقشهٔ ساده)', () async {
    SharedPreferences.setMockInitialValues({
      'local_assistant_memory': jsonEncode({'q1': 'a1', 'q2': 'a2'}),
    });
    await mem.load();
    expect(mem.count, 2);
    expect(mem.lookup('q1'), 'a1');
    final e = mem.lookupEntry('q1');
    expect(e!.source, MemorySource.import);
  });

  test('حذف قدیمی‌ها بر اساس ارزش (کم‌استفاده‌ترین) نه ترتیب ورود', () async {
    await mem.rememberEntry('q1', 'a1'); // بدون استفاده
    await mem.rememberEntry('q2', 'a2');
    await mem.recordHit('q2');
    await mem.recordHit('q2');
    await mem.rememberEntry('q3', 'a3');
    await mem.recordHit('q3');
    await mem.rememberEntry('q4', 'a4');
    await mem.rememberEntry('q5', 'a5');
    await mem.rememberEntry('q6', 'a6');
    // ظرفیت ۶ است؛ ورودی هفتم باعث حذف ضعیف‌ترین (q1 با صفر استفاده) می‌شود
    await mem.rememberEntry('q7', 'a7');

    expect(mem.count, 6);
    expect(mem.lookup('q1'), isNull, reason: 'کم‌استفاده‌ترین باید حذف شود');
    expect(mem.lookup('q2'), isNotNull, reason: 'پراستفاده‌ترین‌ها بمانند');
  });

  test('similarEntries ورودی‌های مرتبط را برمی‌گرداند (برای پرامپت آنلاین)', () async {
    await mem.rememberEntry(
      'بدهی فرهاد چقدره',
      '۲ میلیون',
      source: MemorySource.online,
    );
    final sim = mem.similarEntries('بدهی فرهاد چقدر است؟', limit: 3);
    expect(sim, hasLength(1));
    expect(sim.first.answer, '۲ میلیون');
    expect(sim.first.source, MemorySource.online);
  });

  test('ورودی بی‌اعتبار (degraded) در lookup و similarEntries شرکت نمی‌کند', () async {
    await mem.rememberEntry('سوال بد', 'جواب بد');
    await mem.rate('سوال بد', positive: false); // -0.4
    await mem.rate('سوال بد', positive: false); // -0.8 → حذف
    expect(mem.lookupEntry('سوال بد'), isNull);
    expect(mem.similarEntries('سوال بد'), isEmpty);
  });

  test('stats آمار منبع، استفاده و موضوعات را می‌دهد', () async {
    await mem.rememberEntry('بدهی فرهاد چقدره', 'جواب', source: MemorySource.online);
    await mem.rememberEntry('بدهی مریم چقدره', 'جواب', source: MemorySource.correction);
    await mem.rememberEntry('درآمد امروز چقدره', 'جواب', source: MemorySource.online);
    await mem.recordHit('بدهی فرهاد چقدره');

    final s = mem.stats;
    expect(s.total, 3);
    expect(s.bySource[MemorySource.online], 2);
    expect(s.bySource[MemorySource.correction], 1);
    expect(s.totalHits, 1);
    expect(s.topTopics.first.key, 'بدهی');
  });

  test('export/import نسخهٔ ۲ با حفظ متادیتا', () async {
    await mem.rememberEntry(
      'بدهی فرهاد چقدره',
      '۲ میلیون',
      source: MemorySource.online,
    );
    await mem.recordHit('بدهی فرهاد چقدره');
    final json = mem.exportJson();

    final mem2 = LocalAssistantMemory(storageKey: 'test_mem_v2_other');
    await mem2.importJson(json);
    expect(mem2.count, 1);
    final e = mem2.lookupEntry('بدهی فرهاد چقدره');
    expect(e!.source, MemorySource.online);
    expect(e.useCount, 1);
    expect(e.answer, '۲ میلیون');
  });

  test('نرمال‌سازی هم‌معناها: قرض/وام → بدهی', () async {
    await mem.rememberEntry('قرض فرهاد چقدره', '۲ میلیون');
    expect(mem.lookup('وام فرهاد چقدره'), '۲ میلیون');
  });
}
