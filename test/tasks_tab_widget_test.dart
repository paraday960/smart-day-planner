import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_day_planner/app/app_providers.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/presentation/tasks/tasks_tab.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/availability_repository.dart';
import 'package:smart_day_planner/services/category_budget_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/notification_service.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/security_service.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_response_service.dart';

void main() {
  testWidgets('TasksTab renders empty state with provider overrides', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildAppOverrides(
          taskRepository: TaskRepository(),
          financeRepository: FinanceRepository(),
          goalRepository: GoalRepository(),
          plannedExpenseRepository: PlannedExpenseRepository(),
          debtRepository: DebtRepository(),
          allocationRepository: AllocationRepository(),
          categoryBudgetRepository: CategoryBudgetRepository(),
          availabilityRepository: AvailabilityRepository(),
          conversationMemoryService: ConversationMemoryService(),
          notificationService: NotificationService.instance,
          voiceResponseService: VoiceResponseService.instance,
          securityService: SecurityService.instance,
        ),
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: TasksTab(
                onEdit: _noopTask,
                onComplete: _noopTask,
                onReopen: _noopTask,
                onDelete: _noopTask,
                onTogglePin: _noopTask,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('کارهای باز'), findsOneWidget);
    expect(find.text('کاری باز نیست.'), findsOneWidget);
  });
}

void _noopTask(Task _) {}
