import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/models/money_allocation.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('multi-step debt conversation registers debt', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debtRepository = DebtRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      debtRepository: debtRepository,
      plannedExpenseRepository: PlannedExpenseRepository(),
      allocationRepository: AllocationRepository(),
      conversationMemory: memory,
    );

    final first = await processor.handle('به ممد بدهکارم');
    expect(first, contains('چقدر'));

    final second = await processor.handle('یک میلیون تومان');
    expect(second, contains('تا کی'));

    final third = await processor.handle('تا دو روز دیگه');
    expect(third, contains('ثبت شد'));
    expect(debtRepository.items, hasLength(1));
    expect(debtRepository.items.single.personName, 'ممد');
    expect(debtRepository.items.single.amount, 1000000);
  });

  test('ambiguous reference asks confirmation then allocates money', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debtRepository = DebtRepository();
    final allocationRepository = AllocationRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      debtRepository: debtRepository,
      plannedExpenseRepository: PlannedExpenseRepository(),
      allocationRepository: allocationRepository,
      conversationMemory: memory,
    );

    await processor.handle('به ممد بدهکارم');
    await processor.handle('یک میلیون تومان');
    await processor.handle('تا دو روز دیگه');

    final ask = await processor.handle('پونصد براش کنار بذار');
    expect(ask, contains('تأیید'));
    expect(allocationRepository.items, isEmpty);

    final confirmed = await processor.handle('تأیید');
    expect(confirmed, contains('کنار گذاشته شد'));
    expect(allocationRepository.items, hasLength(1));
    expect(allocationRepository.items.single.targetType, AllocationTargetType.debt);
    expect(allocationRepository.items.single.amount, 500000);
  });
}
