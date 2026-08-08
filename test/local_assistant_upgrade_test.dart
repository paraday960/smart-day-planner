import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/local_assistant.dart';

Task _task({
  required String id,
  required String title,
  int importance = 3,
  int estimatedMinutes = 30,
  EnergyLevel energy = EnergyLevel.medium,
  TaskStatus status = TaskStatus.todo,
}) {
  return Task(
    id: id,
    title: title,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    importance: importance,
    estimatedMinutes: estimatedMinutes,
    energy: energy,
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final assistant = RuleBasedLocalAssistant();
  final tasks = [
    _task(
        id: '1',
        title: 'تماس با مشتری',
        importance: 5,
        estimatedMinutes: 45,
        energy: EnergyLevel.high),
    _task(id: '2', title: 'ثبت گزارش', importance: 2),
  ];

  group('RuleBasedLocalAssistant — intentهای جدید', () {
    test('focus_suggestion', () async {
      final a = await assistant.generate(
          prompt: 'رو چی تمرکز کنم؟', tasks: tasks);
      expect(a, contains('تمرکز'));
    });
    test('free_time', () async {
      final a = await assistant.generate(
          prompt: 'چقدر وقت آزاد دارم', tasks: tasks);
      expect(a, contains('آزاد'));
    });
    test('productivity_tip', () async {
      final a = await assistant.generate(
          prompt: 'یک نکته بهره‌وری بگو', tasks: tasks);
      expect(a, contains('بهره‌وری'));
    });
    test('capability_query', () async {
      final a = await assistant.generate(
          prompt: 'چی بلدی انجام بدی؟', tasks: tasks);
      expect(a, contains('برنامه‌ریزی'));
    });
    test('cancel_or_stop', () async {
      final a = await assistant.generate(prompt: 'بس کن', tasks: tasks);
      expect(a, contains('متوقف'));
    });
    test('reschedule', () async {
      final a = await assistant.generate(
          prompt: 'دوباره برنامه بچین', tasks: tasks);
      expect(a, contains('بازچیدن') || a.contains('بازچیده'), reason: a);
    });
  });

  group('canHandle با اطمینان', () {
    test('شناخته‌شده', () {
      expect(assistant.canHandle('برنامه امروز'), isTrue);
    });
    test('نامرتبط', () {
      expect(assistant.canHandle('کوهنوردی در برف چطور است'), isFalse);
    });
    test('detectIntent', () {
      final m = assistant.detectIntent('برنامه امروز');
      expect(m, isNotNull);
      expect(m!.confidence, greaterThan(0.5));
      expect(m.id, 'today_plan');
    });
  });
}
