abstract class GoalRepositoryPort {
  int get dailyIncomeGoal;
  int get monthlyIncomeGoal;
  int get dailyDeepWorkMinutes;

  Future<void> setGoals({
    required int dailyIncomeGoal,
    required int monthlyIncomeGoal,
    required int dailyDeepWorkMinutes,
  });
}
