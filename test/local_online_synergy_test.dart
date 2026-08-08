import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/services/conversation_router.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/intelligent_assistant_service.dart';
import 'package:smart_day_planner/services/local_assistant.dart';
import 'package:smart_day_planner/services/local_assistant_memory.dart';
import 'package:smart_day_planner/services/local_feedback_learning.dart';
import 'package:smart_day_planner/services/local_online_router.dart';

/// یک بک‌اند آنلاین جعلی که در صورت available بودن پاسخ می‌دهد.
class _FakeOnline implements dynamic {
  bool availableResult;
  int calls = 0;
  String answer;
  _FakeOnline({this.availableResult = true, this.answer = 'پاسخ آنلاین'});

  @override
  dynamic noSuchMethod(Invocation inv) {
    if (inv.memberName == #available) {
      return Future.value(availableResult);
    }
    if (inv.memberName == #generate) {
      calls++;
      return Future.value(answer);
    }
    return super.noSuchMethod(inv);
  }
}

IntelligentAssistantService build({
  required _FakeOnline online,
  LocalOnlineRouter? router,
}) {
  return IntelligentAssistantService(
    online: online as dynamic,
    ruleBased: RuleBasedLocalAssistant(),
    finance: FinanceRepository(),
    goal: GoalRepository(),
    debt: DebtRepository(),
    memory: LocalAssistantMemory(maxEntries: 50),
    feedbackStore: IntentFeedbackStore(seed: 1),
    conversationContext: ConversationContext(),
    onlineRouter: router ?? LocalOnlineRouter(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('intent قوی محلی، آنلاین را صدا نمی‌زند', () async {
    final online = _FakeOnline(availableResult: true);
    final svc = build(online: online);
    await svc.ask(userText: 'برنامه امروز', tasks: const []);
    expect(online.calls, 0);
  });

  test('سؤال بازِ نامفهوم، آنلاین را صدا می‌زند', () async {
    final online = _FakeOnline(availableResult: true, answer: 'توصیه آنلاین');
    final svc = build(online: online);
    final answer =
        await svc.ask(userText: 'چطور می‌توانم بهتر تمرکز کنم؟', tasks: const []);
    expect(online.calls, greaterThan(0));
    expect(answer, contains('آنلاین'));
  });

  test('وقتی آنلاین در دسترس نیست، محلی پاسخ می‌دهد', () async {
    final online = _FakeOnline(availableResult: false);
    final svc = build(online: online);
    final answer =
        await svc.ask(userText: 'برنامه امروز', tasks: const []);
    expect(answer, isNotEmpty);
    expect(online.calls, 0);
  });

  test('روتر سفارشی می‌تواند همه‌چیز را آنلاین کند', () async {
    final online = _FakeOnline(availableResult: true, answer: 'اجباری آنلاین');
    final router = LocalOnlineRouter(confidenceThreshold: 1.0, maxLocalLength: 0);
    final svc = build(online: online, router: router);
    final answer =
        await svc.ask(userText: 'برنامه امروز', tasks: const []);
    expect(answer, contains('اجباری'));
    expect(online.calls, greaterThan(0));
  });
}
