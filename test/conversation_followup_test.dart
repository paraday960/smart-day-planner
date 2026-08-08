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

IntelligentAssistantService build({ConversationContext? ctx}) {
  return IntelligentAssistantService(
    online: null,
    ruleBased: RuleBasedLocalAssistant(),
    finance: FinanceRepository(),
    goal: GoalRepository(),
    debt: DebtRepository(),
    memory: LocalAssistantMemory(maxEntries: 50),
    feedbackStore: IntentFeedbackStore(seed: 1),
    conversationContext: ctx ?? ConversationContext(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AnaphoraDetector پیگیری‌ها را تشخیص می‌دهد', () {
    expect(AnaphoraDetector.isFollowUp('ادامه‌اش چیه'), isTrue);
    expect(AnaphoraDetector.isFollowUp('بعدش چی'), isTrue);
    expect(AnaphoraDetector.isFollowUp('چی شد'), isTrue);
    expect(AnaphoraDetector.isFollowUp('برنامه امروز'), isFalse);
  });

  test('روتر با سابقه، پیگیری را به intent قبلی وصل می‌کند', () {
    final ctx = ConversationContext();
    final router = LocalAssistantRouter(
      detector: const IntentDetector(intents: [
        NluIntent(id: 'today_plan', patterns: ['برنامه امروز'], priority: 40),
      ]),
      context: ctx,
    );
    ctx.addUser('برنامه امروز', intentId: 'today_plan');
    final d = router.route('ادامه‌اش چیه');
    expect(d.kind, RouteKind.followUp);
    expect(d.intentId, 'today_plan');
  });

  test('سرویس: بعد از پرسش برنامه، پیگیری پاسخ مرتبط می‌دهد', () async {
    final ctx = ConversationContext();
    final svc = build(ctx: ctx);

    final first = await svc.ask(userText: 'برنامه امروز', tasks: const []);
    expect(first, isNotEmpty);

    final followUp =
        await svc.ask(userText: 'ادامه‌اش چیه', tasks: const []);
    // باید همان نوع پاسخ (برنامه) باشد نه دیالوگ نامفهوم
    expect(followUp, isNotEmpty);
    expect(followUp.contains('برنامه') || followUp.contains('آزاد') ||
        followUp.contains('کار'), isTrue,
        reason: 'پیگیری باید به موضوع برنامه رجوع کند');
  });

  test('سرویس: پیگیری بدون سابقه، به پاسخ عمومی می‌رسد', () async {
    final svc = build(); // context خالی
    final answer = await svc.ask(userText: 'ادامه‌اش چیه', tasks: const []);
    expect(answer, isNotEmpty);
  });
}
