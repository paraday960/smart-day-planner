import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/services/conversation_router.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/intelligent_assistant_service.dart';
import 'package:smart_day_planner/services/llama_backend.dart';
import 'package:smart_day_planner/services/local_assistant.dart';
import 'package:smart_day_planner/services/local_assistant_memory.dart';
import 'package:smart_day_planner/services/local_feedback_learning.dart';
import 'package:smart_day_planner/services/local_online_router.dart';

class _FakeOnline implements LlmBackend {
  int calls = 0;
  final String response;
  _FakeOnline({this.response = 'پاسخ آموخته‌شده'});
  @override
  Future<bool> get available async => true;
  @override
  Future<String> generate(String prompt) async {
    calls++;
    return response;
  }
}

IntelligentAssistantService build({required _FakeOnline online}) {
  return IntelligentAssistantService(
    online: online,
    ruleBased: RuleBasedLocalAssistant(),
    finance: FinanceRepository(),
    goal: GoalRepository(),
    debt: DebtRepository(),
    memory: LocalAssistantMemory(maxEntries: 50),
    feedbackStore: IntentFeedbackStore(seed: 1),
    conversationContext: ConversationContext(),
    onlineRouter: LocalOnlineRouter(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('حلقه دوطرفه: بار اول آنلاین، بار دوم از حافظه', () async {
    final online = _FakeOnline();
    final svc = build(online: online);
    final a1 = await svc.ask(userText: 'بهترین فیلم کمدی چی ببینم؟', tasks: const []);
    expect(online.calls, 1);
    expect(a1, contains('پاسخ آموخته'));
    final a2 = await svc.ask(userText: 'بهترین فیلم کمدی چی ببینم؟', tasks: const []);
    expect(online.calls, 1, reason: 'بار دوم باید از حافظه بیاید');
    expect(a2, contains('پاسخ آموخته'));
  });

  test('پاسخ fallback شامل Instance of نیست', () async {
    final online = _FakeOnline();
    final svc = build(online: online);
    final a = await svc.ask(userText: 'سؤال نامرتبط فیلم؟', tasks: const []);
    expect(a.contains('Instance of'), isFalse);
  });
}
