import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/work_learning_service.dart';

Task _doneTask({
  required String id,
  required int actualMinutes,
  required DateTime completedAt,
}) {
  return Task(
    id: id,
    title: 'کار $id',
    createdAt: completedAt.subtract(const Duration(hours: 1)),
    actualMinutes: actualMinutes,
    status: TaskStatus.done,
    completedAt: completedAt,
    estimatedMinutes: 30,
  );
}

void main() {
  const service = WorkLearningService();
  final now = DateTime.now();

  group('WorkLearningService: پروفایل کاری', () {
    test('بدون سابقه → پروفایل خالی', () {
      final profile = service.profile(tasks: const [], transactions: const []);
      expect(profile.avgDailyWorkMinutes, 0);
      expect(profile.avgHourlyRate, 0);
      expect(profile.hasEnoughData, isFalse);
    });

    test('میانگین دقیقهٔ کار در روز از کارهای انجام‌شده حساب می‌شود', () {
      final tasks = [
        _doneTask(id: '1', actualMinutes: 120, completedAt: now.subtract(const Duration(days: 1))),
        _doneTask(id: '2', actualMinutes: 60, completedAt: now.subtract(const Duration(days: 1))),
        _doneTask(id: '3', actualMinutes: 90, completedAt: now.subtract(const Duration(days: 2))),
      ];
      final profile = service.profile(tasks: tasks, transactions: const []);
      // ۲ روز کاری: (120+60)/1 روز اول + 90 روز دوم → میانگین (180+90)/2 = 135
      expect(profile.avgDailyWorkMinutes, closeTo(135, 0.01));
      expect(profile.historyDays, 2);
    });

    test('درآمد ساعتی از تراکنش‌های با زمان واقعی محاسبه می‌شود', () {
      final txs = [
        FinanceTransaction(
          id: 't1',
          type: FinanceTransactionType.income,
          amount: 600000, // ۶۰۰ هزار در ۶۰ دقیقه = ۶۰۰ هزار در ساعت
          createdAt: now.subtract(const Duration(days: 2)),
          minutesWorked: 60,
        ),
        FinanceTransaction(
          id: 't2',
          type: FinanceTransactionType.income,
          amount: 900000, // ۹۰۰ هزار در ۹۰ دقیقه = ۶۰۰ هزار در ساعت
          createdAt: now.subtract(const Duration(days: 3)),
          minutesWorked: 90,
        ),
      ];
      final profile = service.profile(tasks: const [], transactions: txs);
      expect(profile.avgHourlyRate, closeTo(600000, 1));
      expect(profile.hasEnoughData, isTrue);
    });

    test('توان روزانه = (دقیقه روزانه / ۶۰) × درآمد ساعتی', () {
      final tasks = [
        _doneTask(id: '1', actualMinutes: 120, completedAt: now.subtract(const Duration(days: 1))),
      ];
      final txs = [
        FinanceTransaction(
          id: 't1',
          type: FinanceTransactionType.income,
          amount: 300000,
          createdAt: now.subtract(const Duration(days: 1)),
          minutesWorked: 60, // ۳۰۰ هزار در ساعت
        ),
      ];
      final profile = service.profile(tasks: tasks, transactions: txs);
      // ۲ ساعت کار در روز × ۳۰۰ هزار = ۶۰۰ هزار توان روزانه
      // مجموع زمان ۱ روز = ۱۲۰ (کار) + ۶۰ (تراکنش) = ۱۸۰ دقیقه
      // توان روزانه = (180/60) × 300000 = 900 هزار
      expect(profile.dailyEarningCapacity, closeTo(900000, 1));
    });

    test('کارهای قدیمی‌تر از ۳۰ روز نادیده گرفته می‌شوند', () {
      final tasks = [
        _doneTask(id: 'old', actualMinutes: 500, completedAt: now.subtract(const Duration(days: 40))),
      ];
      final profile = service.profile(tasks: tasks, transactions: const []);
      expect(profile.avgDailyWorkMinutes, 0);
    });
  });
}
