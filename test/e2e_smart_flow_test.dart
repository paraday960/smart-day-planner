import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/models/money_allocation.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_command_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('end-to-end smart flow: debt -> allocation -> risk', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final allocations = AllocationRepository();
    final planned = PlannedExpenseRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      debtRepository: debts,
      plannedExpenseRepository: planned,
      allocationRepository: allocations,
      conversationMemory: memory,
    );

    var response = await processor.handle('به ممد بدهکارم');
    expect(response, contains('چقدر'));

    response = await processor.handle('یک میلیون تومان');
    expect(response, contains('تا کی'));

    response = await processor.handle('تا دو روز دیگه');
    expect(response, contains('ثبت شد'));
    expect(debts.items.single.amount, 1000000);

    response = await processor.handle('پونصد براش کنار بذار');
    expect(response, contains('تأیید'));

    response = await processor.handle('تأیید');
    expect(response, contains('کنار گذاشته شد'));
    expect(allocations.totalFor(AllocationTargetType.debt, debts.items.single.id), 500000);

    response = await processor.handle('ریسک مالی دارم؟');
    expect(response, contains('ریسک'));
  });
}
