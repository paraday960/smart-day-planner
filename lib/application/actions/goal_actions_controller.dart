import '../../domain/repositories/goal_repository_port.dart';

class GoalInputData {
  const GoalInputData({
    required this.dailyIncomeGoal,
    required this.monthlyIncomeGoal,
    required this.dailyDeepWorkMinutes,
  });

  final int dailyIncomeGoal;
  final int monthlyIncomeGoal;
  final int dailyDeepWorkMinutes;
}

class GoalActionsController {
  const GoalActionsController();

  Future<void> saveGoals({
    required GoalRepositoryPort repository,
    required GoalInputData input,
  }) async {
    await repository.setGoals(
      dailyIncomeGoal: input.dailyIncomeGoal,
      monthlyIncomeGoal: input.monthlyIncomeGoal,
      dailyDeepWorkMinutes: input.dailyDeepWorkMinutes,
    );
  }
}
