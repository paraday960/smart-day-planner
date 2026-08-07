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

VoiceCommandProcessor buildFullProcessor({
  DebtRepository? debts,
  PlannedExpenseRepository? planned,
  AllocationRepository? allocations,
  GoalRepository? goals,
  ConversationMemoryService? memory,
}) {
  return VoiceCommandProcessor(
    taskRepository: TaskRepository(),
    financeRepository: FinanceRepository(),
    goalRepository: goals,
    plannedExpenseRepository: planned,
    debtRepository: debts,
    allocationRepository: allocations,
    conversationMemory: memory,
  );
}

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
    final processor = buildFullProcessor(
      debts: DebtRepository(), planned: planned,
      allocations: AllocationRepository(), goals: GoalRepository(), memory: memory,
    );
    final response = await processor.handle('پانصد هزار برای سفر کنار بذار');
    expect(response, isNot(contains(notConnected)));
  });

  test('S1b: پاسخ پاکت پول شامل «کنار گذاشته شد» است', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final planned = PlannedExpenseRepository();
    await planned.add(PlannedExpenseGoal(
      id: 'p1', title: 'سفر', targetAmount: 3000000,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ));
    final allocations = AllocationRepository();
    final processor = buildFullProcessor(
      debts: DebtRepository(), planned: planned,
      allocations: allocations, goals: GoalRepository(), memory: memory,
    );
    final response = await processor.handle('پانصد هزار برای سفر کنار بذار');
    expect(response, contains('کنار گذاشته شد'));
  });

  test('S2a: ثبت بدهی پاسخ «ثبت شد» دارد', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = buildFullProcessor(
      debts: debts, planned: PlannedExpenseRepository(),
      allocations: AllocationRepository(), goals: GoalRepository(), memory: memory,
    );
    final register = await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    expect(register, contains('ثبت شد'));
  });

  test('S2b: ثبت بدهی در repo ذخیره شد', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = buildFullProcessor(
      debts: debts, planned: PlannedExpenseRepository(),
      allocations: AllocationRepository(), goals: GoalRepository(), memory: memory,
    );
    await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    expect(debts.items, hasLength(1));
  });

  test('S2c: چندبدهی چیزی ثبت میکند', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = buildFullProcessor(
      debts: debts, planned: PlannedExpenseRepository(),
      allocations: AllocationRepository(), goals: GoalRepository(), memory: memory,
    );
    await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    final multi = await processor.handle(
        'به علی و محمد بدهکارم، به علی بیست میلیون، به محمد پنج میلیون، تا ماه آینده');
    expect(multi, isNot(contains(notConnected)));
    expect(debts.items.length, greaterThan(1));
  });

  test('S2d: پرداخت بدهی پاسخ «ثبت شد» دارد', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = buildFullProcessor(
      debts: debts, planned: PlannedExpenseRepository(),
      allocations: AllocationRepository(), goals: GoalRepository(), memory: memory,
    );
    await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    final payment = await processor.handle('به ممد بدهی پرداخت کردم');
    expect(payment, contains('ثبت شد'));
  });

  test('S2e: پرداخت بدهی باقیمانده را کم میکند', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = buildFullProcessor(
      debts: debts, planned: PlannedExpenseRepository(),
      allocations: AllocationRepository(), goals: GoalRepository(), memory: memory,
    );
    await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    await processor.handle('به ممد بدهی پرداخت کردم');
    expect(debts.items.first.remainingAmount, lessThan(debts.items.first.amount));
  });

  test('placeholder', () => expect(1, 1));
}
