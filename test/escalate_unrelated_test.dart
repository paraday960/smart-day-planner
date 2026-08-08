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
import 'package:smart_day_planner/services/local_smart_summary.dart';

class _CountingOnline implements LlmBackend {
  int calls = 0;
  final bool availableResult;
  final String response;
  _CountingOnline({this.availableResult = true, this.response = 'پاسخ آنلاین'});

  @override
  Future<bool> get available async => availableResult;

  @override
  Future<String> generate(String prompt) async {
    calls++;
    return response;
  }
}

IntelligentAssistantService build({
  required _CountingOnline online,
  LocalOnlineRouter? router,
}) {
  return IntelligentAssistantService(
    online: online,
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

  group('رفع باگ: سؤال نامرتبط با برنامه', () {
    test('canAnswerMeaningfully برای سؤال نامرتبط false است', () {
      final a = RuleBasedLocalAssistant();
      expect(a.canAnswerMeaningfully('قیمت دلار امروز چنده؟'), isFalse);
      expect(a.canAnswerMeaningfully('بهترین رستوران تهران کجاست؟'), isFalse);
      expect(a.canAnswerMeaningfully('برنامه امروز چیه؟'), isTrue);
      expect(a.canAnswerMeaningfully('چی کار کنم؟'), isTrue);
    });

    test('isAboutTasks فقط برای عبارات مرتبط true است', () {
      expect(LocalSmartSummary.hasTaskRelatedAnswer('قیمت طلا'), isFalse);
      expect(LocalSmartSummary.hasTaskRelatedAnswer('قیمت دلار امروز'), isFalse);
      expect(LocalSmartSummary.hasTaskRelatedAnswer('برنامه هفته'), isTrue);
      expect(LocalSmartSummary.hasTaskRelatedAnswer('کارهای امروز'), isTrue);
      expect(LocalSmartSummary.hasTaskRelatedAnswer('فیلم خوب معرفی کن'), isFalse);
    });

    test('سؤال نامرتبط به آنلاین ارجاع می‌شود', () async {
      final online = _CountingOnline(response: 'پاسخ آنلاین');
      final svc = build(online: online);
      final answer = await svc.ask(userText: 'قیمت دلار امروز چنده؟', tasks: const []);
      expect(online.calls, greaterThan(0));
      expect(answer, contains('آنلاین'));
      expect(answer, isNot(contains('کار باز')));
    });

    test('تکرار سؤال نامرتبط دوباره آنلاین را صدا می‌زند', () async {
      final online = _CountingOnline(response: 'پاسخ آنلاین');
      final svc = build(online: online);
      // دو سؤال نامرتبطِ متفاوت هر دو باید آنلاین را صدا بزنند.
      await svc.ask(userText: 'بهترین فیلم امسال چی بود؟', tasks: const []);
      final afterFirst = online.calls;
      await svc.ask(userText: 'قیمت طلا الان چنده؟', tasks: const []);
      expect(online.calls, greaterThan(afterFirst),
          reason: 'سؤال نامرتبط دوم هم باید آنلاین را صدا بزند');
    });

    test('وقتی آنلاین نیست، پاسخ عمومی می‌دهد نه لیست کارها', () async {
      final online = _CountingOnline(availableResult: false);
      final svc = build(online: online);
      final answer =
          await svc.ask(userText: 'بهترین رستوران کجاست؟', tasks: const []);
      expect(answer, isNotEmpty);
      expect(answer, isNot(contains('کار باز داری')));
    });
  });
}
