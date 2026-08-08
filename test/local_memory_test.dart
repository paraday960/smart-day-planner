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
  int calls = 0;
  @override
  Future<bool> get available async => true;
  @override
  Future<String> generate(String prompt) async {
    calls++;
    return 'پاسخ آنلاین $calls';
  }
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

  test('بار اول از آنلاین جواب می‌گیرد، بار دوم از محلی (یادگیری)', () async {
    final fake = _FakeOnline();
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
      memory: LocalAssistantMemory.instance,
    );

    // بار اول: آنلاین صدا زده می‌شود.
    final first = await service.ask(userText: 'معنی موفقیت چیست؟', tasks: []);
    expect(fake.calls, 1);
    expect(first, contains('پاسخ آنلاین'));

    // بار دوم: همان سؤال → از محلی جواب بده، آنلاین صدا زده نشود.
    final second = await service.ask(userText: 'معنی موفقیت چیست؟', tasks: []);
    expect(fake.calls, 1, reason: 'باید از حافظهٔ محلی جواب دهد، نه آنلاین');
    expect(second, 'پاسخ آنلاین 1');
  });

  test('سؤال جدید دوباره آنلاین را صدا می‌زند', () async {
    final fake = _FakeOnline();
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
      memory: LocalAssistantMemory.instance,
    );

    await service.ask(userText: 'سوال اول چیست؟', tasks: []);
    await service.ask(userText: 'سوال دوم چیست؟', tasks: []);
    expect(fake.calls, 2, reason: 'دو سؤال متفاوت → دو بار آنلاین');
  });
}
