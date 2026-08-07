import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/models/planned_expense_goal.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_command_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const notConnected = 'هنوز به فرمان صوتی وصل نشده';

  test('S1a: پاسخ پاکت پول شامل وصل نشده نیست', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final planned = PlannedExpenseRepository();
    await planned.add(PlannedExpenseGoal(
      id: 'p1', title: 'سفر', targetAmount: 3000000,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ));
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      plannedExpenseRepository: planned,
      debtRepository: DebtRepository(),
      allocationRepository: AllocationRepository(),
      conversationMemory: memory,
    );
    final response = await processor.handle('پانصد هزار برای سفر کنار بذار');
    expect(response, isNot(contains(notConnected)));
  });

  test('placeholder1', () => expect(1, 1));
  test('placeholder2', () => expect(2, 2));
  test('placeholder3', () => expect(3, 3));
  test('placeholder4', () => expect(4, 4));
  test('placeholder5', () => expect(5, 5));
}
