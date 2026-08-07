import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('sensitive expense can be cancelled before it is stored', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final finance = FinanceRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: finance,
      goalRepository: GoalRepository(),
      debtRepository: DebtRepository(),
      plannedExpenseRepository: PlannedExpenseRepository(),
      allocationRepository: AllocationRepository(),
      conversationMemory: memory,
    );

    final ask = await processor.handle('هزینه یک میلیون تومان ثبت کن');
    expect(ask, contains('تأیید'));
    expect(finance.transactions, isEmpty);

    final cancel = await processor.handle('لغو');
    expect(cancel, contains('انجام نشد'));
    expect(finance.transactions, isEmpty);
  });

  test('sensitive debt can be cancelled before it is stored', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      debtRepository: debts,
      plannedExpenseRepository: PlannedExpenseRepository(),
      allocationRepository: AllocationRepository(),
      conversationMemory: memory,
    );

    final ask = await processor.handle('به ممد یک میلیون تومان بدهکارم تا دو روز دیگه');
    expect(ask, contains('تأیید'));
    expect(debts.items, isEmpty);

    await processor.handle('لغو');
    expect(debts.items, isEmpty);
  });
}
