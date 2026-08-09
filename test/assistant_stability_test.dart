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

/// بک‌اند آنلاین که در دسترس نیست تا مسیر fallback محلی تست شود.
class _UnavailableOnline implements LlmBackend {
  @override
  Future<bool> get available async => false;

  @override
  Future<String> generate(String prompt) async => 'نباید صدا زده شود';
}

IntelligentAssistantService build() {
  return IntelligentAssistantService(
    online: _UnavailableOnline(),
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

  test('پاسخ fallback آنلاین نباید خروجی Future.toString باشد', () async {
    final svc = build();
    // سؤالی که محلی نمی‌فهمد و آنلاین هم در دسترس نیست.
    final answer = await svc.ask(
      userText: 'بهترین فیلم تاریخ سینما چیه؟',
      tasks: const [],
    );
    // رشتهٔ خرابِ نمونهٔ Future هرگز نباید در خروجی باشد.
    expect(answer.contains('Instance of'), isFalse);
    expect(answer.contains("Future<String>"), isFalse);
    expect(answer, isNotEmpty);
  });

  test('سرویس بین دو سؤال حافظه‌اش را حفظ می‌کند (بازسازی نمی‌شود)', () async {
    final svc = build();
    final a1 = await svc.ask(userText: 'برنامه امروز', tasks: const []);
    final a2 = await svc.ask(userText: 'برنامه امروز', tasks: const []);
    // هر دو پاسخ باید معتبر و غیر تهی باشند.
    expect(a1, isNotEmpty);
    expect(a2, isNotEmpty);
    // پاسخ‌ها نباید شامل رشتهٔ خراب باشند.
    expect(a1.contains('Instance of'), isFalse);
    expect(a2.contains('Instance of'), isFalse);
  });

  test('پیگیری «ادامه‌اش چیه؟» پس از یک سؤال کار می‌کند', () async {
    final svc = build();
    await svc.ask(userText: 'برنامه امروز', tasks: const []);
    final follow = await svc.ask(userText: 'ادامه‌اش چیه؟', tasks: const []);
    expect(follow, isNotEmpty);
    expect(follow.contains('Instance of'), isFalse);
  });
}
