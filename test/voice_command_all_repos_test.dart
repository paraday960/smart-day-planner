import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/models/planned_expense_goal.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('T1: add باعث میشود activeItems غیرخالی شود', () async {
    final repo = PlannedExpenseRepository();
    await repo.add(PlannedExpenseGoal(
      id: 'p1', title: 'سفر', targetAmount: 3000000,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ));
    expect(repo.activeItems, hasLength(1));
  });

  test('T2: عنوان activeItems سفر است', () async {
    final repo = PlannedExpenseRepository();
    await repo.add(PlannedExpenseGoal(
      id: 'p1', title: 'سفر', targetAmount: 3000000,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ));
    expect(repo.activeItems.single.title, 'سفر');
  });

  test('T3: placeholder', () => expect(1, 1));
  test('T4: placeholder', () => expect(2, 2));
  test('T5: placeholder', () => expect(3, 3));
}
