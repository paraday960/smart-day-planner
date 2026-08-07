import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/actions/allocation_actions_controller.dart';
import 'feature_flags.dart';
import '../application/actions/backup_actions_controller.dart';
import '../application/actions/debt_actions_controller.dart';
import '../application/actions/goal_actions_controller.dart';
import '../application/actions/report_actions_controller.dart';
import '../application/actions/security_actions_controller.dart';
import '../application/dashboard/dashboard_controller.dart';
import '../application/finance/finance_actions_controller.dart';
import '../application/finance/finance_controller.dart';
import '../application/home/home_coordinator.dart';
import '../application/tasks/task_actions_controller.dart';
import '../domain/usecases/calculate_required_daily_income.dart';
import '../services/allocation_repository.dart';
import '../services/availability_repository.dart';
import '../services/category_budget_repository.dart';
import '../domain/services/calendar_service_port.dart';
import '../domain/services/notification_service_port.dart';
import '../domain/services/share_file_service_port.dart';
import '../domain/services/voice_response_port.dart';
import '../services/calendar_service.dart';
import '../services/chart_insight_service.dart';
import '../services/command_confidence_service.dart';
import '../services/conversation_memory_service.dart';
import '../services/debt_planning_service.dart';
import '../services/debt_repository.dart';
import '../services/envelope_planning_service.dart';
import '../services/finance_assistant.dart';
import '../services/finance_repository.dart';
import '../services/forecast_service.dart';
import '../services/finance_insights_service.dart';
import '../services/goal_planning_service.dart';
import '../services/goal_repository.dart';
import '../services/advanced_habit_learning_service.dart';
import '../services/ai_brain_service.dart';
import '../services/brain_memory_service.dart';
import '../services/feedback_learning_service.dart';
import '../services/predictive_scheduler_service.dart';
import '../services/autonomous_agent_service.dart';
import '../services/habit_insight_service.dart';
import '../services/hybrid_local_assistant.dart';
import '../services/llama_backend.dart';
import '../services/local_assistant.dart';
import '../services/online_llm_backend.dart';
import '../services/work_learning_service.dart';
import '../services/notification_service.dart';
import '../services/planned_expense_repository.dart';
import '../services/security_service.dart';
import '../services/share_file_service.dart';
import '../services/smart_planner.dart';
import '../services/task_repository.dart';
import '../services/voice_response_service.dart';
import '../services/time_aware_planner.dart';

final smartPlannerProvider =
    Provider<SmartPlanner>((ref) => const SmartPlanner());
final financeInsightsServiceProvider =
    Provider<FinanceInsightsService>((ref) => const FinanceInsightsService());
final workLearningServiceProvider =
    Provider<WorkLearningService>((ref) => const WorkLearningService());

/// دستیار گفتگوی اصلی: هیبرید.
///
/// ترتیب هوش:
/// 1. هوش مصنوعی آنلاین رایگان (Gemini/Groq) — وقتی کلید تنظیم شده باشد
/// 2. LLM محلی (llama.cpp) — وقتی `ENABLE_LOCAL_LLM=true` و مدل GGUF موجود باشد
/// 3. موتور قانون‌محور — همیشه به‌عنوان پشتیبان
///
/// بدون کلید آنلاین و بدون مدل محلی، خودکار به موتور قانون‌محور برمی‌گردد.
final assistantProvider = Provider<LocalLlmAdapter>((ref) {
  return HybridLocalAssistant(
    llm: PriorityLlmBackend([
      OnlineLlmBackend(),
      LlamaCppBackend(),
    ]),
    enabled: FeatureFlags.enableOnlineAi,
    timeout: const Duration(seconds: 45),
    fallback: RuleBasedLocalAssistant(
      planner: ref.watch(smartPlannerProvider),
      context: AssistantContext(
        finance: ref.watch(financeRepositoryProvider),
        forecast: ref.watch(forecastServiceProvider),
        insights: ref.watch(financeInsightsServiceProvider),
        availability: ref.watch(availabilityRepositoryProvider).settings,
        debts: ref.watch(debtRepositoryProvider).activeItems,
        workProfile: ref.watch(workLearningServiceProvider).profile(
          tasks: ref.watch(taskRepositoryProvider).tasks,
          transactions: ref.watch(financeRepositoryProvider).transactions,
        ),
        taskRepo: ref.watch(taskRepositoryProvider),
        goalRepo: ref.watch(goalRepositoryProvider),
        plannedRepo: ref.watch(plannedExpenseRepositoryProvider),
        debtRepo: ref.watch(debtRepositoryProvider),
        allocationRepo: ref.watch(allocationRepositoryProvider),
        budgetRepo: ref.watch(categoryBudgetRepositoryProvider),
      ),
    ),
  );
});

final dashboardControllerProvider =
    Provider<DashboardController>((ref) => const DashboardController());
final financeControllerProvider =
    Provider<FinanceController>((ref) => const FinanceController());
final financeAssistantProvider =
    Provider<FinanceAssistant>((ref) => const FinanceAssistant());
final envelopePlanningServiceProvider =
    Provider<EnvelopePlanningService>((ref) => const EnvelopePlanningService());
final goalPlanningServiceProvider =
    Provider<GoalPlanningService>((ref) => const GoalPlanningService());
final debtPlanningServiceProvider =
    Provider<DebtPlanningService>((ref) => const DebtPlanningService());
final forecastServiceProvider =
    Provider<ForecastService>((ref) => const ForecastService());
final brainMemoryServiceProvider =
    Provider<BrainMemoryService>((ref) => BrainMemoryService());

final feedbackLearningServiceProvider =
    Provider<FeedbackLearningService>((ref) => FeedbackLearningService());

final predictiveSchedulerServiceProvider =
    Provider<PredictiveSchedulerService>((ref) => const PredictiveSchedulerService());

final aiBrainServiceProvider =
    Provider<AIBrainService>((ref) => const AIBrainService());

final autonomousAgentServiceProvider =
    Provider<AutonomousAgentService>((ref) => const AutonomousAgentService(mode: AutonomousMode.hybrid));

final advancedHabitLearningServiceProvider =
    Provider<AdvancedHabitLearningService>((ref) => const AdvancedHabitLearningService());
final habitInsightServiceProvider =
    Provider<HabitInsightService>((ref) => const HabitInsightService());
final chartInsightServiceProvider =
    Provider<ChartInsightService>((ref) => const ChartInsightService());
final commandConfidenceServiceProvider = Provider<CommandConfidenceService>(
    (ref) => const CommandConfidenceService());
final timeAwarePlannerProvider =
    Provider<TimeAwarePlanner>((ref) => const TimeAwarePlanner());
final taskActionsControllerProvider =
    Provider<TaskActionsController>((ref) => const TaskActionsController());
final financeActionsControllerProvider = Provider<FinanceActionsController>(
    (ref) => const FinanceActionsController());
final debtActionsControllerProvider =
    Provider<DebtActionsController>((ref) => const DebtActionsController());
final allocationActionsControllerProvider =
    Provider<AllocationActionsController>(
        (ref) => const AllocationActionsController());
final securityActionsControllerProvider = Provider<SecurityActionsController>(
    (ref) => const SecurityActionsController());
final backupActionsControllerProvider =
    Provider<BackupActionsController>((ref) => const BackupActionsController());
final goalActionsControllerProvider =
    Provider<GoalActionsController>((ref) => const GoalActionsController());
final reportActionsControllerProvider = Provider<ReportActionsController>(
  (ref) => ReportActionsController(
      shareFileService: ref.watch(shareFileServiceProvider)),
);
final calculateRequiredDailyIncomeProvider =
    Provider<CalculateRequiredDailyIncome>(
        (ref) => const CalculateRequiredDailyIncome());

// Repository/service providers. In production they are overridden in main.dart
// with the already initialized instances. In tests they can be overridden with fakes.
final taskRepositoryProvider = Provider<TaskRepository>(
    (ref) => throw UnimplementedError('TaskRepository override نشده است.'));
final financeRepositoryProvider = Provider<FinanceRepository>(
    (ref) => throw UnimplementedError('FinanceRepository override نشده است.'));
final goalRepositoryProvider = Provider<GoalRepository>(
    (ref) => throw UnimplementedError('GoalRepository override نشده است.'));
final plannedExpenseRepositoryProvider = Provider<PlannedExpenseRepository>(
    (ref) => throw UnimplementedError(
        'PlannedExpenseRepository override نشده است.'));
final debtRepositoryProvider = Provider<DebtRepository>(
    (ref) => throw UnimplementedError('DebtRepository override نشده است.'));
final allocationRepositoryProvider = Provider<AllocationRepository>((ref) =>
    throw UnimplementedError('AllocationRepository override نشده است.'));
final categoryBudgetRepositoryProvider = Provider<CategoryBudgetRepository>(
    (ref) => throw UnimplementedError(
        'CategoryBudgetRepository override نشده است.'));
final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) =>
    throw UnimplementedError('AvailabilityRepository override نشده است.'));
final conversationMemoryServiceProvider = Provider<ConversationMemoryService>(
    (ref) => throw UnimplementedError(
        'ConversationMemoryService override نشده است.'));
final notificationServiceProvider =
    Provider<NotificationServicePort>((ref) => NotificationService.instance);
final calendarServiceProvider =
    Provider<CalendarServicePort>((ref) => CalendarService());
final shareFileServiceProvider =
    Provider<ShareFileServicePort>((ref) => const ShareFileService());
final voiceResponseServiceProvider =
    Provider<VoiceResponsePort>((ref) => VoiceResponseService.instance);
final securityServiceProvider =
    Provider<SecurityService>((ref) => SecurityService.instance);

List<Override> buildAppOverrides({
  required TaskRepository taskRepository,
  required FinanceRepository financeRepository,
  required GoalRepository goalRepository,
  required PlannedExpenseRepository plannedExpenseRepository,
  required DebtRepository debtRepository,
  required AllocationRepository allocationRepository,
  required CategoryBudgetRepository categoryBudgetRepository,
  required AvailabilityRepository availabilityRepository,
  required ConversationMemoryService conversationMemoryService,
  required NotificationServicePort notificationService,
  required VoiceResponsePort voiceResponseService,
  required SecurityService securityService,
}) {
  return [
    taskRepositoryProvider.overrideWith((ref) => taskRepository),
    financeRepositoryProvider.overrideWith((ref) => financeRepository),
    goalRepositoryProvider.overrideWith((ref) => goalRepository),
    plannedExpenseRepositoryProvider
        .overrideWith((ref) => plannedExpenseRepository),
    debtRepositoryProvider.overrideWith((ref) => debtRepository),
    allocationRepositoryProvider.overrideWith((ref) => allocationRepository),
    categoryBudgetRepositoryProvider
        .overrideWith((ref) => categoryBudgetRepository),
    availabilityRepositoryProvider
        .overrideWith((ref) => availabilityRepository),
    conversationMemoryServiceProvider
        .overrideWith((ref) => conversationMemoryService),
    notificationServiceProvider.overrideWith((ref) => notificationService),
    voiceResponseServiceProvider.overrideWith((ref) => voiceResponseService),
    securityServiceProvider.overrideWith((ref) => securityService),
  ];
}

final homeCoordinatorProvider = Provider<HomeCoordinator>((ref) {
  return HomeCoordinator(
    taskRepository: ref.watch(taskRepositoryProvider),
    financeRepository: ref.watch(financeRepositoryProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
    plannedExpenseRepository: ref.watch(plannedExpenseRepositoryProvider),
    debtRepository: ref.watch(debtRepositoryProvider),
    allocationRepository: ref.watch(allocationRepositoryProvider),
    categoryBudgetRepository: ref.watch(categoryBudgetRepositoryProvider),
    availabilityRepository: ref.watch(availabilityRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
    securityService: ref.watch(securityServiceProvider),
    taskActions: ref.watch(taskActionsControllerProvider),
    financeActions: ref.watch(financeActionsControllerProvider),
    debtActions: ref.watch(debtActionsControllerProvider),
    allocationActions: ref.watch(allocationActionsControllerProvider),
    goalActions: ref.watch(goalActionsControllerProvider),
    backupActions: ref.watch(backupActionsControllerProvider),
    securityActions: ref.watch(securityActionsControllerProvider),
    reportActions: ref.watch(reportActionsControllerProvider),
  );
});
