import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/intelligent_assistant_service.dart';
import 'package:smart_day_planner/services/local_assistant.dart';
import 'package:smart_day_planner/services/local_assistant_memory.dart';
import 'package:smart_day_planner/services/local_feedback_learning.dart';

IntelligentAssistantService build({IntentFeedbackStore? fb}) {
  return IntelligentAssistantService(
    online: null,
    ruleBased: RuleBasedLocalAssistant(),
    finance: FinanceRepository(),
    goal: GoalRepository(),
    debt: DebtRepository(),
    memory: LocalAssistantMemory(maxEntries: 50),
    feedbackStore: fb ?? IntentFeedbackStore(seed: 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('پاسخ به intent محلی، موفقیت ثبت می‌کند', () async {
    final fb = IntentFeedbackStore(seed: 1);
    final svc = build(fb: fb);
    await svc.ask(userText: 'برنامه امروز', tasks: const []);
    expect(fb.stats['today_plan']?.success ?? 0, greaterThan(0));
  });

  test('بازنویسی هم‌مضمون سؤال، شکست ثبت می‌کند', () async {
    final fb = IntentFeedbackStore(seed: 2);
    final svc = build(fb: fb);
    await svc.ask(userText: 'برنامه امروز چیه', tasks: const []);
    await svc.ask(userText: 'برنامه امروزمو بچین', tasks: const []);
    expect(fb.stats['today_plan']?.failure ?? 0, greaterThan(0));
  });

  test('سؤال متفاوت، شکست ثبت نمی‌کند', () async {
    final fb = IntentFeedbackStore(seed: 3);
    final svc = build(fb: fb);
    await svc.ask(userText: 'برنامه امروز', tasks: const []);
    final before = fb.stats['today_plan']?.failure ?? 0;
    await svc.ask(userText: 'سلام', tasks: const []);
    expect(fb.stats['today_plan']?.failure ?? 0, before);
  });

  test('تصحیح صریح، شکست intent محلی را ثبت می‌کند', () async {
    final fb = IntentFeedbackStore(seed: 4);
    final svc = build(fb: fb);
    await svc.ask(userText: 'برنامه امروز', tasks: const []);
    await svc.ask(userText: 'نه اشتباهه، ۱۰۰ هزار بود', tasks: const []);
    expect(fb.stats['today_plan']?.failure ?? 0, greaterThan(0));
  });
}
