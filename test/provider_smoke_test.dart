import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_day_planner/app/app_providers.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/availability_repository.dart';
import 'package:smart_day_planner/services/category_budget_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/security_service.dart';
import 'package:smart_day_planner/services/task_repository.dart';

import 'fakes/fake_platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository providers can be overridden for tests', () {
    final taskRepository = TaskRepository();
    final container = ProviderContainer(
      overrides: buildAppOverrides(
        taskRepository: taskRepository,
        financeRepository: FinanceRepository(),
        goalRepository: GoalRepository(),
        plannedExpenseRepository: PlannedExpenseRepository(),
        debtRepository: DebtRepository(),
        allocationRepository: AllocationRepository(),
        categoryBudgetRepository: CategoryBudgetRepository(),
        availabilityRepository: AvailabilityRepository(),
        conversationMemoryService: ConversationMemoryService(),
        notificationService: FakeNotificationService(),
        voiceResponseService: FakeVoiceResponseService(),
        securityService: SecurityService.instance,
      ),
    );
    addTearDown(container.dispose);

    expect(container.read(taskRepositoryProvider), same(taskRepository));
    expect(container.read(taskActionsControllerProvider), isNotNull);
    expect(container.read(reportActionsControllerProvider), isNotNull);
  });
}
