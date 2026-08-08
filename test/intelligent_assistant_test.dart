import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/intelligent_assistant_service.dart';
import 'package:smart_day_planner/services/llama_backend.dart';
import 'package:smart_day_planner/services/local_assistant.dart';
import 'package:smart_day_planner/services/local_assistant_memory.dart';

class _FakeOnline implements LlmBackend {
  _FakeOnline(this.reply);
  final String reply;
  String? lastPrompt;
  int calls = 0;

  @override
  Future<bool> get available async => true;

  @override
  Future<String> generate(String prompt) async {
    calls++;
    lastPrompt = prompt;
    return reply;
  }
}

/// هوش آنلاین با پاسخ قابل‌تغییر — برای تست خوددرمانی.
class _MutableOnline implements LlmBackend {
  String reply = 'پاسخ اول';
  int calls = 0;

  @override
  Future<bool> get available async => true;

  @override
  Future<String> generate(String prompt) async {
    calls++;
    return reply;
  }
}

/// هوش آنلاین خراب — برای تست عدم یادگیری از fallback.
class _FailingOnline implements LlmBackend {
  @override
  Future<bool> get available async => true;

  @override
  Future<String> generate(String prompt) async {
    throw Exception('اتصال ناموفق');
  }
}

/// یک سؤال که قانون‌محور نمی‌فهمد (intent ندارد).
const String kUnknownQuestion = 'بهترین روش برای یادگیری گیتار چیست؟';

IntelligentAssistantService _buildService(LlmBackend? online) {
  return IntelligentAssistantService(
    online: online,
    ruleBased: RuleBasedLocalAssistant(),
    finance: FinanceRepository(),
    goal: GoalRepository(),
    debt: DebtRepository(),
    memory: LocalAssistantMemory.instance,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalAssistantMemory.instance.reset();
  });

  test('سؤال نامفهوم برای قانون‌محور → آنلاین استفاده می‌شود و context را می‌بیند',
      () async {
    final fake = _FakeOnline('پاسخ هوش آنلاین');
    final service = _buildService(fake);

    // مطمئن شویم قانون‌محور این را نمی‌فهمد.
    expect(RuleBasedLocalAssistant().canHandle(kUnknownQuestion), isFalse);

    final answer = await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(answer, 'پاسخ هوش آنلاین');
    // prompt باید شامل دادهٔ واقعی برنامه باشد.
    expect(fake.lastPrompt, contains('درآمد کل'));
  });

  test('سؤالی که قانون‌محور می‌فهمد → آنلاین صدا زده نمی‌شود (محلی جواب می‌دهد)',
      () async {
    final fake = _FakeOnline('پاسخ آنلاین');
    final service = _buildService(fake);

    // «سلام» را قانون‌محور می‌فهمد → محلی، بدون آنلاین.
    await service.ask(userText: 'سلام', tasks: []);
    expect(fake.calls, 0, reason: 'سؤال قابل‌فهم محلی نباید آنلاین را صدا بزند');
  });

  test('سؤال نامفهوم: بار اول آنلاین و یادگیری، بار دوم محلی', () async {
    final fake = _FakeOnline('پاسخ یادگیری');
    final service = _buildService(fake);

    // بار اول: آنلاین (نامفهوم برای محلی) + یادگیری
    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1);
    expect(
      LocalAssistantMemory.instance.lookupEntry(kUnknownQuestion)?.source,
      MemorySource.online,
      reason: 'ورودی حافظه باید منبع «آنلاین» داشته باشد',
    );

    // بار دوم: همان سؤال → از حافظهٔ محلی، بدون آنلاین
    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1, reason: 'باید از حافظهٔ محلی جواب دهد');
  });

  test('وقتی هوش آنلاین در دسترس نباشد، fallback قانون‌محور استفاده می‌شود',
      () async {
    final service = _buildService(null);

    final answer = await service.ask(userText: 'سلام', tasks: []);
    expect(answer, isNotEmpty);
  });

  test('تصحیح کاربر، ورودی حافظه را با جواب تمیز به‌روزرسانی می‌کند', () async {
    final fake = _FakeOnline('پاسخ آنلاین');
    final service = _buildService(fake);

    // ۱) سؤال نامفهوم → آنلاین جواب می‌دهد و یاد می‌گیرد
    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1);

    // ۲) کاربر تصحیح می‌کند
    await service.ask(userText: 'نه اشتباهه، ۲ میلیون بود', tasks: []);

    // ۳) دفعه بعد از حافظهٔ تصحیح‌شده جواب می‌دهد، بدون آنلاین
    final answer = await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1, reason: 'باید از حافظهٔ تصحیح‌شده جواب دهد');
    expect(answer, contains('۲'));
    expect(answer, isNot(contains('تصحیح کاربر: نه اشتباهه')),
        reason: 'جواب تصحیح‌شده باید تمیز باشد، نه متن خام');
    expect(
      LocalAssistantMemory.instance.lookupEntry(kUnknownQuestion)?.source,
      MemorySource.correction,
      reason: 'منبع ورودی باید «تصحیح» باشد',
    );
  });

  test('بازخورد مثبت، امتیاز ورودی حافظه را بالا می‌برد', () async {
    final fake = _FakeOnline('پاسخ خوب');
    final service = _buildService(fake);

    await service.ask(userText: kUnknownQuestion, tasks: []);
    await service.ask(userText: kUnknownQuestion, tasks: []); // از حافظه

    final before = LocalAssistantMemory.instance.lookupEntry(kUnknownQuestion)!;
    expect(before.feedbackScore, 0);

    final ack = await service.ask(userText: 'خوب بود ممنون', tasks: []);
    expect(ack, contains('ممنون'));

    final after = LocalAssistantMemory.instance.lookupEntry(kUnknownQuestion)!;
    expect(after.feedbackScore, greaterThan(0));
    expect(fake.calls, 1, reason: 'بازخورد نباید آنلاین را صدا بزند');
  });

  test('بازخورد منفی → خوددرمانی: پرسش دوباره از آنلاین و جایگزینی جواب',
      () async {
    final fake = _MutableOnline();
    final service = _buildService(fake);

    // ۱) اولین پاسخ آنلاین یاد گرفته می‌شود
    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1);

    // ۲) هوش آنلاین حالا جواب بهتری دارد
    fake.reply = 'پاسخ بهتر آنلاین';

    // ۳) کاربر بازخورد منفی می‌دهد → خوددرمانی (یک بار آنلاین دیگر)
    final ack = await service.ask(userText: 'بد بود', tasks: []);
    expect(ack, contains('جایگزین'));
    expect(fake.calls, 2, reason: 'خوددرمانی باید دوباره از آنلاین بپرسد');

    // ۴) سؤال بعدی → جواب بهتر از حافظه، بدون آنلاین
    final answer = await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(answer, 'پاسخ بهتر آنلاین');
    expect(fake.calls, 2, reason: 'جواب بهتر باید در حافظه ذخیره شده باشد');
  });

  test('وقتی آنلاین خطا می‌دهد، پاسخ fallback در حافظه ذخیره نمی‌شود', () async {
    final service = _buildService(_FailingOnline());

    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(LocalAssistantMemory.instance.count, 0,
        reason: 'فقط پاسخ واقعی آنلاین یاد گرفته می‌شود');
  });

  test('پرامپت آنلاین شامل دانش یادگرفته‌شدهٔ قبلی است (تعامل دوطرفه)', () async {
    final fake = _FakeOnline('پاسخ');
    final service = _buildService(fake);

    // دانش قبلی را در حافظه می‌کاریم (مثل این که قبلاً از آنلاین یاد گرفته)
    await LocalAssistantMemory.instance.rememberEntry(
      'بهترین روش برای یادگیری گیتار چیست؟',
      'جواب یادگیری گیتار',
      source: MemorySource.online,
    );

    // سؤال جدیدِ مرتبط (نه آن‌قدر نزدیک که lookup بزند، نه آن‌قدر دور که نادیده بگیرد)
    const related = 'راه‌های بهتر برای یادگیری گیتار چیست؟';
    expect(LocalAssistantMemory.instance.lookupEntry(related), isNull,
        reason: 'نباید مستقیم از حافظه جواب دهد');
    expect(
      LocalAssistantMemory.instance.similarEntries(related),
      isNotEmpty,
      reason: 'اما باید به‌عنوان دانش مرتبط شناخته شود',
    );

    final answer = await service.ask(userText: related, tasks: []);
    expect(answer, 'پاسخ');
    expect(fake.lastPrompt, contains('دانش یادگرفته‌شدهٔ قبلی'));
    expect(fake.lastPrompt, contains('جواب یادگیری گیتار'));
  });
}
