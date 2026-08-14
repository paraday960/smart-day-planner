import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/advanced_habit_learning_service.dart';

Task _task({required String id, DateTime? completedAt}) {
  return Task(
    id: id,
    title: 'کار $id',
    importance: 3,
    estimatedMinutes: 30,
    createdAt: DateTime(2026, 8, 1),
    completedAt: completedAt,
    status: TaskStatus.done,
    energy: EnergyLevel.medium,
  );
}

void main() {
  const svc = AdvancedHabitLearningService();

  test('X: helper task construction', () {
    final t = _task(id: '1', completedAt: DateTime(2026, 8, 5));
    expect(t.isDone, true);
    expect(t.status, TaskStatus.done);
  });

  test('Y: analyze empty', () {
    final p = svc.analyze(tasks: [], transactions: []);
    expect(p.hasEnoughData, isFalse);
    expect(p.streakDays, 0);
    expect(p.completionRate, 0);
  });


  group('focusRecommendation و focusInsight', () {
    Task _done(String id, String category, int est, int actual) {
      return Task(
        id: id,
        title: 'کار $id',
        category: category,
        importance: 3,
        estimatedMinutes: est,
        actualMinutes: actual,
        createdAt: DateTime(2026, 8, 1),
        completedAt: DateTime(2026, 8, 5),
        status: TaskStatus.done,
        energy: EnergyLevel.medium,
      );
    }

    test('تخمین خوش‌بینانه (واقعی ۲ برابر) → بلوک کوتاه پومودورو', () {
      final profile = svc.analyze(
        tasks: [_done('1', 'کار', 30, 60), _done('2', 'کار', 30, 60)],
        transactions: [],
        now: DateTime(2026, 8, 10),
      );
      final rec = svc.focusRecommendation(profile);
      expect(rec.suggestedBlockMinutes, 25);
      expect(rec.reason, contains('پومودورو'));
    });

    test('سریع‌تر از تخمین → بلوک بلند ۶۰ دقیقه‌ای', () {
      final profile = svc.analyze(
        tasks: [_done('1', 'کار', 60, 30), _done('2', 'کار', 60, 30)],
        transactions: [],
        now: DateTime(2026, 8, 10),
      );
      expect(svc.focusRecommendation(profile).suggestedBlockMinutes, 60);
    });

    test('بدون دادهٔ کافی → بلوک پیش‌فرض ۴۵ دقیقه', () {
      final profile = svc.analyze(tasks: const [], transactions: const []);
      expect(svc.focusRecommendation(profile).suggestedBlockMinutes, 45);
    });

    test('focusInsight جملهٔ فارسی با ایموجی می‌سازد', () {
      final profile = svc.analyze(
        tasks: [_done('1', 'کار', 30, 60), _done('2', 'کار', 30, 60)],
        transactions: [],
        now: DateTime(2026, 8, 10),
      );
      expect(svc.focusInsight(profile), contains('🎯'));
    });
  });
}
