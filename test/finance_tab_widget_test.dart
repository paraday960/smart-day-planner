import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_day_planner/app/app_providers.dart';
import 'package:smart_day_planner/models/debt_item.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/planned_expense_goal.dart';
import 'package:smart_day_planner/presentation/finance/finance_tab.dart';
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
  testWidgets('FinanceTab renders key sections with provider overrides', (tester) async {
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
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: FinanceTab(
                onAddTransaction: _noopTransactionType,
                onSetGoals: _noop,
                onAddPlannedExpense: _noop,
                onDeletePlannedExpense: _noopPlannedExpense,
                onAddDebt: _noop,
                onPayDebt: _noopDebt,
                onDeleteDebt: _noopDebt,
                onAllocateToDebt: _noopDebt,
                onAllocateToPlannedExpense: _noopPlannedExpense,
                onSetCategoryBudget: _noop,
                onDelete: _noopTransaction,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('حسابدار شخصی هوشمند'), findsOneWidget);
    expect(find.text('درآمد امروز'), findsOneWidget);
  });
}

void _noop() {}
void _noopTransactionType(FinanceTransactionType _) {}
void _noopPlannedExpense(PlannedExpenseGoal _) {}
void _noopDebt(DebtItem _) {}
void _noopTransaction(FinanceTransaction _) {}
