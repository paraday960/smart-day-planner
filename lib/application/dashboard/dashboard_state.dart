import '../../models/scheduled_item.dart';

class DashboardState {
  const DashboardState({
    required this.openCount,
    required this.doneTodayCount,
    required this.suggestions,
    required this.decisionInsights,
    required this.weeklyInsights,
    required this.habitInsights,
    required this.plannedExpenseMessages,
    required this.debtMessages,
    required this.todayPlan,
  });

  final int openCount;
  final int doneTodayCount;
  final List<String> suggestions;
  final List<String> decisionInsights;
  final List<String> weeklyInsights;
  final List<String> habitInsights;
  final List<String> plannedExpenseMessages;
  final List<String> debtMessages;
  final List<ScheduledItem> todayPlan;

  bool get hasUrgentMoneyMessage => plannedExpenseMessages.isNotEmpty || debtMessages.isNotEmpty;
}
