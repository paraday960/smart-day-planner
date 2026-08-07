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

  test('تست ۱: پاکت پول با همهٔ repoها', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final planned = PlannedExpenseRepository();
    await planned.add(PlannedExpenseGoal(
      id: 'p1', title: 'سفر', targetAmount: 3000000,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ));
    final allocations = AllocationRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      plannedExpenseRepository: planned,
      debtRepository: DebtRepository(),
      allocationRepository: allocations,
      conversationMemory: memory,
    );
    final response = await processor.handle('پانصد هزار برای سفر کنار بذار');
    expect(response, isNot(contains(notConnected)));
    expect(response, contains('کنار گذاشته شد'));
    expect(allocations.items, hasLength(1));
    expect(allocations.items.single.amount, 500000);
  });

  test('تست ۲: بدهی ثبت/پرداخت/چندبدهی', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      goalRepository: GoalRepository(),
      plannedExpenseRepository: PlannedExpenseRepository(),
      debtRepository: debts,
      allocationRepository: AllocationRepository(),
      conversationMemory: memory,
    );
    final register = await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    expect(register, isNot(contains(notConnected)));
    expect(register, contains('ثبت شد'));
    expect(debts.items, hasLength(1));

    final multi = await processor.handle(
        'به علی و محمد بدهکارم، به علی بیست میلیون، به محمد پنج میلیون، تا ماه آینده');
    expect(multi, isNot(contains(notConnected)));
    expect(debts.items.length, greaterThan(1));

    final payment = await processor.handle('به ممد بدهی پرداخت کردم');
    expect(payment, isNot(contains(notConnected)));
    expect(payment, contains('ثبت شد'));
    expect(debts.items.first.remainingAmount, lessThan(debts.items.first.amount));
  });

  test('placeholder 3', () => expect(3, 3));
  test('placeholder 4', () => expect(4, 4));
  test('placeholder 5', () => expect(5, 5));
}
