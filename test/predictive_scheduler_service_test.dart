import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/advanced_habit_learning_service.dart';
import 'package:smart_day_planner/services/predictive_scheduler_service.dart';

void main() {
  const svc = PredictiveSchedulerService();

  test('forecast with no data returns zero avg', () {
    final points = svc.forecast30Days(transactions: [], type: FinanceTransactionType.expense);
    expect(points.length, 30);
    expect(points.first.predictedValue, 0);
  });

  test('forecast with data', () {
    final txs = List.generate(20, (i) => FinanceTransaction(
      id: 'tx$i', type: FinanceTransactionType.expense, amount: 100000 + i*10000, category: 'خرید',
      createdAt: DateTime(2026, 7, 10).add(Duration(days: i)), note: '',
    ));
    final points = svc.forecast30Days(transactions: txs, type: FinanceTransactionType.expense, now: DateTime(2026, 8, 6));
    expect(points.length, 30);
    expect(points.first.confidence, inInclusiveRange(0.3, 0.9));
    expect(points.first.predictedValue, greaterThan(0));
  });

  test('autoSchedule returns prioritized', () {
    final now = DateTime(2026, 8, 6, 10);
    final tasks = [
      Task(id: '1', title: 'عقب افتاده', category: 'کاری', importance: 5, estimatedMinutes: 30, actualMinutes: null, createdAt: DateTime(2026, 8, 1), dueAt: now.subtract(const Duration(days: 1)), status: TaskStatus.todo, energy: EnergyLevel.high),
      Task(id: '2', title: 'عادی', category: 'خرید', importance: 2, estimatedMinutes: 15, actualMinutes: null, createdAt: DateTime(2026, 8, 1), dueAt: now.add(const Duration(days: 5)), status: TaskStatus.todo, energy: EnergyLevel.low),
    ];
    final habit = const AdvancedHabitLearningService().analyze(tasks: tasks, transactions: [], now: now);
    final scheduled = svc.autoSchedule(tasks: tasks, habitProfile: habit, now: now);
    expect(scheduled.length, 2);
    expect(scheduled.first.task.id, '1'); // overdue first
  });

  test('warnings', () {
    final txs = [
      FinanceTransaction(id: '1', type: FinanceTransactionType.expense, amount: 2000000, category: 'خرید', createdAt: DateTime(2026, 8, 5), note: ''),
    ];
    final tasks = [
      Task(id: '1', title: 'کار', category: 'کاری', importance: 3, estimatedMinutes: 30, actualMinutes: null, createdAt: DateTime(2026, 8, 1), dueAt: DateTime(2026, 8, 7), status: TaskStatus.todo, energy: EnergyLevel.medium),
    ];
    final warnings = svc.next7DaysWarnings(transactions: txs, tasks: tasks, now: DateTime(2026, 8, 6));
    expect(warnings.isNotEmpty, isTrue);
  });
}
