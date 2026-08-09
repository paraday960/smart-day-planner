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
import 'package:smart_day_planner/models/task.dart';

class _OnlineYes implements LlmBackend {
  final String response;
  int calls = 0;
  _OnlineYes(this.response);
  @override
  Future<bool> get available async => true;
  @override
  Future<String> generate(String prompt) async {
    calls++;
    return response;
  }
}

class _OnlineNo implements LlmBackend {
  @override
  Future<bool> get available async => false;
  @override
  Future<String> generate(String prompt) async => 'ONLINE';
}

IntelligentAssistantService build({LlmBackend? online}) {
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

Task _t(String title) => Task(
  id: title,
  title: title,
  createdAt: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('تجربهٔ کاربری دستیار', () {
    test('سلام → پاسخ دوستانه', () async {
      final svc = build(online: _OnlineNo());
      final a = await svc.ask(userText: 'سلام', tasks: []);
      expect(a, isNotEmpty);
      expect(a.contains('سلام') || a.contains('درود') || a.contains('سلامتی'), isTrue,
          reason: 'به سلام باید سلام جواب بدهد، نه خلاصه کارها');
    });

    test('برنامه امروز با کارها → لیست کارها', () async {
      final svc = build(online: _OnlineNo());
      final a = await svc.ask(userText: 'امروز چیکار کنم؟', tasks: [_t('نوشتن گزارش'), _t('تماس با مشتری')]);
      expect(a, isNotEmpty);
      // باید به کارها اشاره کند
      expect(
        a.contains('نوشتن گزارش') || a.contains('تماس با مشتری') || a.contains('کار'),
        isTrue,
        reason: 'باید به کارهای کاربر اشاره کند',
      );
    });

    test('سؤال نامرتبط بدون آنلاین → پیام واضح، نه لیست کارها', () async {
      final svc = build(online: _OnlineNo());
      final a = await svc.ask(userText: 'بهترین فیلم کمدی چیه؟', tasks: [_t('کار ۱')]);
      expect(a, isNotEmpty);
      // نباید خلاصه کارها را بدهد
      expect(a.contains('کار باز داری'), isFalse,
          reason: 'نباید برای سؤال نامرتبط خلاصه کارها را بدهد');
      // نباید رشتهٔ خراب Future باشد
      expect(a.contains('Instance of'), isFalse);
      expect(a.contains('Future<'), isFalse);
    });

    test('سؤال نامرتبط با آنلاین → پاسخ آنلاین و یادگیری', () async {
      final online = _OnlineYes('پاسخ آنلاین هوشمند');
      final svc = build(online: online);
      final a1 = await svc.ask(userText: 'بهترین فیلم کمدی چیه؟', tasks: []);
      expect(online.calls, 1);
      expect(a1, 'پاسخ آنلاین هوشمند');
      // بار دوم باید از حافظه بیاید، نه آنلاین
      final a2 = await svc.ask(userText: 'بهترین فیلم کمدی چیه؟', tasks: []);
      expect(online.calls, 1, reason: 'بار دوم نباید آنلاین صدا زده شود');
      expect(a2, 'پاسخ آنلاین هوشمند');
    });

    test('پیگیری بعد از سؤال مرتبط → پاسخ می‌دهد', () async {
      final svc = build(online: _OnlineNo());
      await svc.ask(userText: 'امروز چیکار کنم؟', tasks: [_t('کار مهم')]);
      final follow = await svc.ask(userText: 'ادامه‌اش چیه؟', tasks: [_t('کار مهم')]);
      expect(follow, isNotEmpty);
      expect(follow.contains('Instance of'), isFalse);
    });

    test('چند سؤال پشت سر هم → پاسخ معنادار و بدون خرابی', () async {
      final svc = build(online: _OnlineNo());
      final qs = ['سلام', 'برنامه امروز', 'چی کار کنم؟', 'ممنون'];
      for (final q in qs) {
        final a = await svc.ask(userText: q, tasks: [_t('کار الف'), _t('کار ب')]);
        expect(a, isNotEmpty, reason: 'پاسخ به «$q» نباید خالی باشد');
        expect(a.contains('Instance of'), isFalse, reason: 'پاسخ به «$q» نباید خراب باشد');
        expect(a.length < 500, isTrue, reason: 'پاسخ به «$q» نباید خیلی بلند باشد');
      }
    });
  });
}
