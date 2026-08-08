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

/// یک سؤال که قانون‌محور نمی‌فهمد (intent ندارد).
const String kUnknownQuestion = 'بهترین روش برای یادگیری گیتار چیست؟';

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
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
      memory: LocalAssistantMemory.instance,
    );

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
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
      memory: LocalAssistantMemory.instance,
    );

    // «سلام» را قانون‌محور می‌فهمد → محلی، بدون آنلاین.
    await service.ask(userText: 'سلام', tasks: []);
    expect(fake.calls, 0, reason: 'سؤال قابل‌فهم محلی نباید آنلاین را صدا بزند');
  });

  test('سؤال نامفهوم: بار اول آنلاین و یادگیری، بار دوم محلی', () async {
    final fake = _FakeOnline('پاسخ یادگیری');
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
      memory: LocalAssistantMemory.instance,
    );

    // بار اول: آنلاین (نامفهوم برای محلی) + یادگیری
    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1);

    // بار دوم: همان سؤال → از حافظهٔ محلی، بدون آنلاین
    await service.ask(userText: kUnknownQuestion, tasks: []);
    expect(fake.calls, 1, reason: 'باید از حافظهٔ محلی جواب دهد');
  });

  test('وقتی هوش آنلاین در دسترس نباشد، fallback قانون‌محور استفاده می‌شود',
      () async {
    final service = IntelligentAssistantService(
      online: null,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
      memory: LocalAssistantMemory.instance,
    );

    final answer = await service.ask(userText: 'سلام', tasks: []);
    expect(answer, isNotEmpty);
  });
}
