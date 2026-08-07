import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/ai_brain_service.dart';
import 'package:smart_day_planner/services/finance_repository.dart';

Task _task({required String id, bool isDone = true, DateTime? dueAt, bool overdue = false}) {
  final now = DateTime(2026, 8, 6);
  return Task(
    id: id,
    title: 'کار \$id',
    category: 'کاری',
    importance: 3,
    estimatedMinutes: 30,
    actualMinutes: 30,
    dueAt: dueAt ?? (overdue ? now.subtract(const Duration(days: 1)) : now.add(const Duration(days: 2))),
    createdAt: DateTime(2026, 8, 1),
    completedAt: isDone ? now : null,
    status: isDone ? TaskStatus.done : TaskStatus.todo,
    energy: EnergyLevel.medium,
  );
}

void main() {
  test('brain score 0-100', () {
    const brain = AIBrainService();
    final finance = FinanceRepository();
    final tasks = [
      _task(id: '1', isDone: true),
      _task(id: '2', isDone: true),
      _task(id: '3', isDone: false, overdue: true),
    ];
    final profile = brain.analyze(tasks: tasks, transactions: [], finance: finance);
    expect(profile.brainScore, inInclusiveRange(0, 100));
    expect(profile.mood, isNotEmpty);
    expect(profile.nextAction, isNotEmpty);
    expect(profile.personalizedInsights, isNotEmpty);
  });

  test('brain with transactions', () {
    const brain = AIBrainService();
    final finance = FinanceRepository();
    final txs = [
      FinanceTransaction(id: '1', type: FinanceTransactionType.income, amount: 5000000, category: 'کاری', createdAt: DateTime(2026, 8, 5), note: '', minutesWorked: 60),
      FinanceTransaction(id: '2', type: FinanceTransactionType.expense, amount: 2000000, category: 'خرید', createdAt: DateTime(2026, 8, 5), note: ''),
    ];
    final tasks = [_task(id: '1'), _task(id: '2', isDone: false)];
    final profile = brain.analyze(tasks: tasks, transactions: txs, finance: finance);
    expect(profile.habitProfile, isNotNull);
    expect(profile.brainScore, inInclusiveRange(0, 100));
  });

  test('morning briefing not empty', () {
    const brain = AIBrainService();
    final finance = FinanceRepository();
    final tasks = [_task(id: '1'), _task(id: '2', isDone: false)];
    final profile = brain.analyze(tasks: tasks, transactions: [], finance: finance);
    final briefing = brain.morningBriefing(profile, tasks);
    expect(briefing, contains('صبح بخیر'));
    expect(briefing.length, greaterThan(20));
  });
}
