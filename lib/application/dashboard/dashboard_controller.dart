import '../../models/task.dart';
import '../../services/debt_planning_service.dart';
import '../../services/debt_repository.dart';
import '../../services/finance_repository.dart';
import '../../services/goal_planning_service.dart';
import '../../services/goal_repository.dart';
import '../../services/habit_insight_service.dart';
import '../../services/planned_expense_repository.dart';
import '../../services/smart_insights_service.dart';
import '../../services/smart_planner.dart';
import 'dashboard_state.dart';

class DashboardController {
  const DashboardController({
    SmartPlanner planner = const SmartPlanner(),
    SmartInsightsService insights = const SmartInsightsService(),
    GoalPlanningService goalPlanning = const GoalPlanningService(),
    DebtPlanningService debtPlanning = const DebtPlanningService(),
    HabitInsightService habitInsight = const HabitInsightService(),
  })  : _planner = planner,
        _insights = insights,
        _goalPlanning = goalPlanning,
        _debtPlanning = debtPlanning,
        _habitInsight = habitInsight;

  final SmartPlanner _planner;
  final SmartInsightsService _insights;
  final GoalPlanningService _goalPlanning;
  final DebtPlanningService _debtPlanning;
  final HabitInsightService _habitInsight;

  DashboardState build({
    required List<Task> tasks,
    required FinanceRepository financeRepository,
    required GoalRepository goalRepository,
    required PlannedExpenseRepository plannedExpenseRepository,
    required DebtRepository debtRepository,
  }) {
    final now = DateTime.now();
    final doneToday = tasks.where((task) {
      final completedAt = task.completedAt;
      return task.isDone &&
          completedAt != null &&
          completedAt.year == now.year &&
          completedAt.month == now.month &&
          completedAt.day == now.day;
    }).length;

    return DashboardState(
      openCount: tasks.where((task) => !task.isDone).length,
      doneTodayCount: doneToday,
      suggestions: _planner.suggestions(tasks),
      decisionInsights: _insights.decisionInsights(
        tasks: tasks,
        finance: financeRepository,
        goals: goalRepository,
      ),
      weeklyInsights: _insights.weeklyPerformance(tasks: tasks, finance: financeRepository),
      habitInsights: _habitInsight.insights(tasks: tasks, financeRepository: financeRepository),
      plannedExpenseMessages: _goalPlanning.smartMessages(
        plannedExpenseRepository.activeItems,
        financeRepository,
      ),
      debtMessages: _debtPlanning.smartMessages(
        debtRepository.activeItems,
        financeRepository,
      ),
      todayPlan: _planner.buildTodayPlan(tasks),
    );
  }
}
