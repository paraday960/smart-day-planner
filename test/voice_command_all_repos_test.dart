import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_day_planner/models/debt_item.dart';
import 'package:smart_day_planner/models/planned_expense_goal.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_command_processor.dart';

/// شکاف شمارهٔ ۵ در docs/KNOWN_GAPS.md:
/// مطمئن می‌شویم وقتی [VoiceCommandProcessor] با **همهٔ** repositoryها ساخته
/// می‌شود (مسیر تولید — `AutonomousAgentService` همیشه همه را پاس می‌دهد)،
/// هیچ‌کدام از پیام‌های «هنوز به فرمان صوتی وصل نشده» برنمی‌گردد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  VoiceCommandProcessor buildProcessor({
    required DebtRepository debts,
    required PlannedExpenseRepository planned,
    required AllocationRepository allocations,
    required GoalRepository goals,
    required ConversationMemoryService memory,
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

  const notConnected = 'هنوز به فرمان صوتی وصل نشده';

  test('پاکت پول: با همهٔ repoها، «کنار بذار» بدون پیام وصل‌نشده کار می‌کند',
      () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final planned = PlannedExpenseRepository();
    // یک هزینهٔ آیندهٔ فعال تا مسیر پاکت پول واقعاً اجرا شود
    await planned.add(PlannedExpenseGoal(
      id: 'p1',
      title: 'سفر',
      targetAmount: 3000000,
      dueAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    ));
    final allocations = AllocationRepository();
    final processor = buildProcessor(
      debts: DebtRepository(),
      planned: planned,
      allocations: allocations,
      goals: GoalRepository(),
      memory: memory,
    );

    final response = await processor.handle('پانصد هزار برای سفر کنار بذار');
    expect(response, isNot(contains(notConnected)));
    expect(response, contains('کنار گذاشته شد'));
    expect(allocations.items, hasLength(1));
    expect(allocations.items.single.amount, 500000);
  });

  test('بدهی: ثبت، پرداخت و چندبدهی بدون پیام وصل‌نشده', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final processor = buildProcessor(
      debts: debts,
      planned: PlannedExpenseRepository(),
      allocations: AllocationRepository(),
      goals: GoalRepository(),
      memory: memory,
    );

    // ثبت تک‌بدهی (مبلغ کم → بدون تأیید)
    final register = await processor.handle('به ممد پنجاه هزار تومان بدهکارم تا دو روز دیگه');
    expect(register, isNot(contains(notConnected)));
    expect(register, contains('ثبت شد'));
    expect(debts.items, hasLength(1));

    // ثبت چندبدهی
    final multi = await processor.handle(
        'به علی و محمد بدهکارم، به علی بیست میلیون، به محمد پنج میلیون، تا ماه آینده');
    expect(multi, isNot(contains(notConnected)));
    expect(multi, contains('بدهی ثبت شد'));
    expect(debts.items, hasLength(3));

    // پرداخت بدهی
    final payment = await processor.handle('به ممد بدهی پرداخت کردم');
    expect(payment, isNot(contains(notConnected)));
    expect(payment, contains('ثبت شد'));
    expect(debts.items.first.remainingAmount, lessThan(debts.items.first.amount));
  });

  test('هزینهٔ آینده و هدف: بدون پیام وصل‌نشده (با تأیید حساس)', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final planned = PlannedExpenseRepository();
    final goals = GoalRepository();
    final processor = buildProcessor(
      debts: DebtRepository(),
      planned: planned,
      allocations: AllocationRepository(),
      goals: goals,
      memory: memory,
    );

    // هزینهٔ آینده → مبلغ ۱ میلیون = تأیید حساس
    final ask = await processor.handle('هفته دیگه میخوام برم بیرون و یک میلیون تومان خرج داره');
    expect(ask, isNot(contains(notConnected)));
    expect(ask, contains('برای اطمینان'));

    final confirmed = await processor.handle('تأیید');
    expect(confirmed, isNot(contains(notConnected)));
    expect(confirmed, contains('ثبت شد'));
    expect(planned.items, hasLength(1));

    // هدف درآمد
    final goal = await processor.handle('هدف درآمد ماهانه یک میلیون');
    expect(goal, isNot(contains(notConnected)));
    expect(goal, contains('تنظیم شد'));
    expect(goals.monthlyIncomeGoal, 1000000);
  });

  test('سناریوهای پیش‌بینی (کار نکردن/ریسک/ساعت) با همهٔ repoها', () async {
    final memory = ConversationMemoryService();
    await memory.load();
    final debts = DebtRepository();
    final planned = PlannedExpenseRepository();
    await debts.add(DebtItem(
      id: 'd1',
      type: DebtType.debt,
      personName: 'ممد',
      amount: 1000000,
      dueAt: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
    ));
    await planned.add(PlannedExpenseGoal(
      id: 'p1',
      title: 'سفر',
      targetAmount: 2000000,
      dueAt: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
    ));
    final processor = buildProcessor(
      debts: debts,
      planned: planned,
      allocations: AllocationRepository(),
      goals: GoalRepository(),
      memory: memory,
    );

    final noWork = await processor.handle('اگه فردا کار نکنم چی میشه');
    expect(noWork, isNot(contains(notConnected)));
    expect(noWork, contains('فردا'));

    final risk = await processor.handle('ریسک مالی دارم؟');
    expect(risk, isNot(contains(notConnected)));

    final hours = await processor.handle('اگه امروز سه ساعت کار کنم چی میشه');
    expect(hours, isNot(contains(notConnected)));
  });

  test('پیام دفاعی «وصل نشده» فقط وقتی repo ناقص باشد برمی‌گردد', () async {
    // قرارداد: پیام‌های دفاعی برای حالت null نگه داشته شده‌اند؛
    // با repo ناقص باید همان پیام فارسی قدیمی بیاید (نه کرش).
    final memory = ConversationMemoryService();
    await memory.load();
    final processor = VoiceCommandProcessor(
      taskRepository: TaskRepository(),
      financeRepository: FinanceRepository(),
      conversationMemory: memory,
      // goalRepository / plannedExpenseRepository / debtRepository / allocationRepository = null
    );

    final response = await processor.handle('پانصد هزار برای سفر کنار بذار');
    expect(response, contains(notConnected));
  });
}
