import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/intelligent_assistant_service.dart';
import 'package:smart_day_planner/services/llama_backend.dart';
import 'package:smart_day_planner/services/local_assistant.dart';

class _FakeOnline implements LlmBackend {
  _FakeOnline(this.reply);
  final String reply;
  String? lastPrompt;

  @override
  Future<bool> get available async => true;

  @override
  Future<String> generate(String prompt) async {
    lastPrompt = prompt;
    return reply;
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
  });

  test('وقتی هوش آنلاین موجود است، از آن استفاده می‌شود و context برنامه را می‌بیند',
      () async {
    final fake = _FakeOnline('پاسخ هوش آنلاین');
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
    );

    final answer = await service.ask(userText: 'وضعیت مالی من چطوره؟', tasks: []);

    expect(answer, 'پاسخ هوش آنلاین');
    // prompt باید شامل دادهٔ واقعی برنامه باشد.
    expect(fake.lastPrompt, contains('وضعیت مالی'));
    expect(fake.lastPrompt, contains('درآمد کل'));
  });

  test('وقتی هوش آنلاین در دسترس نباشد، fallback قانون‌محور استفاده می‌شود',
      () async {
    final service = IntelligentAssistantService(
      online: null,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
    );

    // سلام → پاسخ خوش‌آمد از قانون‌محور.
    final answer = await service.ask(userText: 'سلام', tasks: []);
    expect(answer, isNotEmpty);
  });

  test('حافظهٔ مکالمه: درخواست دوم شامل تاریخچهٔ قبلی است', () async {
    final fake = _FakeOnline('پاسخ');
    final service = IntelligentAssistantService(
      online: fake,
      ruleBased: RuleBasedLocalAssistant(),
      finance: FinanceRepository(),
      goal: GoalRepository(),
      debt: DebtRepository(),
    );

    await service.ask(userText: 'سلام', tasks: []);
    await service.ask(userText: 'بگو چیکار کنم', tasks: []);

    // در prompt دوم باید «کاربر: سلام» (تاریخچه) دیده شود.
    expect(fake.lastPrompt, contains('کاربر: سلام'));
  });
}
