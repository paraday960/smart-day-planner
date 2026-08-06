import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/advanced_habit_learning_service.dart';

Task _task({required String id, required String category, int est = 30, int? actual, DateTime? completedAt, bool isDone = true, DateTime? dueAt}) {
  return Task(
    id: id,
    title: 'کار $id',
    category: category,
    importance: 3,
    estimatedMinutes: est,
    actualMinutes: actual,
    dueAt: dueAt,
    createdAt: DateTime(2026, 8, 1),
    completedAt: completedAt,
    status: isDone ? TaskStatus.done : TaskStatus.open,
    energy: EnergyLevel.medium,
  );
}

FinanceTransaction _tx({required int amount, required FinanceTransactionType type, DateTime? date, int? minutes}) {
  return FinanceTransaction(
    id: 'tx_${amount}_${date?.day}',
    type: type,
    amount: amount,
    category: 'کاری',
    createdAt: date ?? DateTime(2026, 8, 1),
    note: 'test',
    minutesWorked: minutes,
    hourlyRate: minutes != null && minutes > 0 ? amount / minutes * 60 : null,
  );
}

void main() {
  const svc = AdvancedHabitLearningService();

  test('empty data -> empty profile', () {
    final p = svc.analyze(tasks: [], transactions: []);
    expect(p.hasEnoughData, isFalse);
    expect(p.streakDays, 0);
    expect(p.completionRate, 0);
  });

  test('streak calculation', () {
    final now = DateTime(2026, 8, 6);
    final tasks = [
      _task(id: '1', category: 'کار', completedAt: DateTime(2026, 8, 6, 10)),
      _task(id: '2', category: 'کار', completedAt: DateTime(2026, 8, 5, 10)),
      _task(id: '3', category: 'کار', completedAt: DateTime(2026, 8, 4, 10)),
    ];
    final p = svc.analyze(tasks: tasks, transactions: [], now: now);
    expect(p.streakDays, 3);
  });

  test('completion rate', () {
    final tasks = [
      _task(id: '1', category: 'a', isDone: true, completedAt: DateTime(2026, 8, 5)),
      _task(id: '2', category: 'a', isDone: true, completedAt: DateTime(2026, 8, 5)),
      _task(id: '3', category: 'a', isDone: false),
      _task(id: '4', category: 'a', isDone: false),
    ];
    final p = svc.analyze(tasks: tasks, transactions: []);
    expect(p.completionRate, 0.5);
    expect(p.totalCompleted, 2);
    expect(p.totalOpen, 2);
  });

  test('category habits accuracy', () {
    final tasks = [
      _task(id: '1', category: 'پروژه', est: 30, actual: 45, completedAt: DateTime(2026, 8, 5)),
      _task(id: '2', category: 'پروژه', est: 30, actual: 45, completedAt: DateTime(2026, 8, 4)),
      _task(id: '3', category: 'خرید', est: 20, actual: 10, completedAt: DateTime(2026, 8, 5)),
      _task(id: '4', category: 'خرید', est: 20, actual: 10, completedAt: DateTime(2026, 8, 4)),
    ];
    final p = svc.analyze(tasks: tasks, transactions: []);
    expect(p.categoryHabits.length, 2);
    final proj = p.categoryHabits.firstWhere((c) => c.category == 'پروژه');
    expect(proj.accuracyRatio, closeTo(1.5, 0.01));
  });

  test('suggestions not empty', () {
    final tasks = [
      _task(id: '1', category: 'کار', est: 30, actual: 30, completedAt: DateTime(2026, 8, 6, 9)),
      _task(id: '2', category: 'کار', est: 30, actual: 30, completedAt: DateTime(2026, 8, 6, 10)),
      _task(id: '3', category: 'کار', est: 30, actual: 30, completedAt: DateTime(2026, 8, 5, 9)),
    ];
    final txs = [
      _tx(amount: 1000000, type: FinanceTransactionType.income, date: DateTime(2026, 8, 5), minutes: 60),
      _tx(amount: 200000, type: FinanceTransactionType.expense, date: DateTime(2026, 8, 5)),
    ];
    final p = svc.analyze(tasks: tasks, transactions: txs, now: DateTime(2026, 8, 6, 12));
    final sug = svc.suggestions(p, now: DateTime(2026, 8, 6, 12));
    expect(sug.isNotEmpty, isTrue);
  });

  test('predicted expense', () {
    final now = DateTime(2026, 8, 6);
    final txs = [
      _tx(amount: 1000000, type: FinanceTransactionType.expense, date: DateTime(2026, 8, 5)),
      _tx(amount: 1000000, type: FinanceTransactionType.expense, date: DateTime(2026, 8, 4)),
      _tx(amount: 500000, type: FinanceTransactionType.income, date: DateTime(2026, 8, 5)),
    ];
    final p = svc.analyze(tasks: [], transactions: txs, now: now);
    expect(p.predictedMonthlyExpense, greaterThan(0));
  });
}
