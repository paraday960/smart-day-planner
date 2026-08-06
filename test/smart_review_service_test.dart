import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/smart_review_service.dart';

Task _task({
  required String id,
  bool done = false,
  int actualMinutes = 30,
  DateTime? completedAt,
  DateTime? dueAt,
}) {
  return Task(
    id: id,
    title: 'کار $id',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    actualMinutes: done ? actualMinutes : null,
    status: done ? TaskStatus.done : TaskStatus.todo,
    completedAt: completedAt,
    dueAt: dueAt,
    estimatedMinutes: 30,
  );
}

FinanceTransaction _tx({
  required String id,
  required FinanceTransactionType type,
  required int amount,
  required DateTime createdAt,
  String category = 'عمومی',
}) {
  return FinanceTransaction(
    id: id,
    type: type,
    amount: amount,
    createdAt: createdAt,
    category: category,
  );
}

void main() {
  const service = SmartReviewService();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('dayReview', () {
    test('آمار امروز: کارها، زمان، درآمد، هزینه', () {
      final tasks = [
        _task(
          id: '1',
          done: true,
          actualMinutes: 60,
          completedAt: today.add(const Duration(hours: 10)),
        ),
        _task(
          id: '2',
          done: true,
          actualMinutes: 30,
          completedAt: today.add(const Duration(hours: 12)),
        ),
        _task(id: '3', done: false, dueAt: today),
      ];
      final txs = [
        _tx(
            id: 'i1',
            type: FinanceTransactionType.income,
            amount: 500000,
            createdAt: today),
        _tx(
            id: 'e1',
            type: FinanceTransactionType.expense,
            amount: 120000,
            createdAt: today,
            category: 'خوراک'),
        _tx(
            id: 'e2',
            type: FinanceTransactionType.expense,
            amount: 80000,
            createdAt: today,
            category: 'خوراک'),
        // خارج از امروز — نباید شمرده شود
        _tx(
            id: 'e3',
            type: FinanceTransactionType.expense,
            amount: 999999,
            createdAt: today.subtract(const Duration(days: 1)),
            category: 'خرید'),
      ];

      final review =
          service.dayReview(tasks: tasks, transactions: txs, now: now);
      expect(review.tasksDone, 2);
      expect(review.tasksLeft, 1);
      expect(review.minutesWorked, 90);
      expect(review.income, 500000);
      expect(review.expense, 200000);
      expect(review.topCategory, 'خوراک');
      expect(review.topCategoryAmount, 200000);
      // ۲ از ۳ = ۶۶٪
      expect(review.focusScore, 67); // 2 از 3 = 66.7٪ → round 67
    });

    test('هیچ کاری نباشد → focus صفر', () {
      final review =
          service.dayReview(tasks: const [], transactions: const [], now: now);
      expect(review.focusScore, 0);
      expect(review.tasksDone, 0);
    });
  });

  group('weekReview', () {
    test('مجموع هفته و بهترین روز', () {
      final tasks = [
        _task(
            id: '1',
            done: true,
            completedAt: today.subtract(const Duration(days: 1))),
        _task(
            id: '2',
            done: true,
            completedAt: today.subtract(const Duration(days: 1))),
        _task(
            id: '3',
            done: true,
            completedAt: today.subtract(const Duration(days: 3))),
        _task(
            id: '4',
            done: true,
            completedAt: today.subtract(const Duration(days: 20))), // خارج هفته
      ];
      final txs = [
        _tx(
            id: 'i1',
            type: FinanceTransactionType.income,
            amount: 3000000,
            createdAt: today.subtract(const Duration(days: 2))),
        _tx(
            id: 'e1',
            type: FinanceTransactionType.expense,
            amount: 400000,
            createdAt: today.subtract(const Duration(days: 2))),
      ];

      final review =
          service.weekReview(tasks: tasks, transactions: txs, now: now);
      expect(review.tasksDone, 3);
      expect(review.income, 3000000);
      expect(review.expense, 400000);
      // بهترین روز = دیروز با ۲ کار
      expect(review.bestDayTasks, 2);
      expect(
        review.bestDay!
            .difference(today.subtract(const Duration(days: 1)))
            .inDays
            .abs(),
        0,
      );
    });

    test('متن خلاصه هفته شامل موارد کلیدی است', () {
      final txs = [
        _tx(
            id: 'i1',
            type: FinanceTransactionType.income,
            amount: 1000000,
            createdAt: today.subtract(const Duration(days: 1))),
        _tx(
            id: 'e1',
            type: FinanceTransactionType.expense,
            amount: 1500000,
            createdAt: today.subtract(const Duration(days: 1))),
      ];
      final text =
          service.weekSummaryText(tasks: const [], transactions: txs, now: now);
      expect(text, contains('خلاصهٔ هفته'));
      expect(text, contains('درآمد'));
      expect(text, contains('هزینه'));
      expect(text, contains('خرج هفته از درآمد بیشتر'));
    });
  });

  group('daySummaryText', () {
    test('متن فارسی شامل امتیاز تمرکز است', () {
      final tasks = [
        _task(
            id: '1',
            done: true,
            actualMinutes: 45,
            completedAt: today.add(const Duration(hours: 9))),
      ];
      final text = service.daySummaryText(
          tasks: tasks, transactions: const [], now: now);
      expect(text, contains('خلاصهٔ امروز'));
      expect(text, contains('امتیاز تمرکز'));
    });
  });
}
