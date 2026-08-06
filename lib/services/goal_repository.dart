import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/goal_repository_port.dart';

class GoalRepository extends ChangeNotifier implements GoalRepositoryPort {
  static const _dailyIncomeGoalKey = 'smart_day_planner.goals.daily_income';
  static const _monthlyIncomeGoalKey = 'smart_day_planner.goals.monthly_income';
  static const _dailyDeepWorkMinutesKey = 'smart_day_planner.goals.daily_deep_work_minutes';

  int _dailyIncomeGoal = 0;
  int _monthlyIncomeGoal = 0;
  int _dailyDeepWorkMinutes = 120;
  bool _loaded = false;

  @override
  int get dailyIncomeGoal => _dailyIncomeGoal;
  @override
  int get monthlyIncomeGoal => _monthlyIncomeGoal;
  @override
  int get dailyDeepWorkMinutes => _dailyDeepWorkMinutes;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyIncomeGoal = prefs.getInt(_dailyIncomeGoalKey) ?? 0;
    _monthlyIncomeGoal = prefs.getInt(_monthlyIncomeGoalKey) ?? 0;
    _dailyDeepWorkMinutes = prefs.getInt(_dailyDeepWorkMinutesKey) ?? 120;
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> setGoals({
    required int dailyIncomeGoal,
    required int monthlyIncomeGoal,
    required int dailyDeepWorkMinutes,
  }) async {
    _dailyIncomeGoal = dailyIncomeGoal.clamp(0, 1000000000000).toInt();
    _monthlyIncomeGoal = monthlyIncomeGoal.clamp(0, 1000000000000).toInt();
    _dailyDeepWorkMinutes = dailyDeepWorkMinutes.clamp(0, 24 * 60).toInt();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyIncomeGoalKey, _dailyIncomeGoal);
    await prefs.setInt(_monthlyIncomeGoalKey, _monthlyIncomeGoal);
    await prefs.setInt(_dailyDeepWorkMinutesKey, _dailyDeepWorkMinutes);
    notifyListeners();
  }

  Future<void> setDailyIncomeGoal(int value) async {
    await setGoals(
      dailyIncomeGoal: value,
      monthlyIncomeGoal: _monthlyIncomeGoal,
      dailyDeepWorkMinutes: _dailyDeepWorkMinutes,
    );
  }

  Future<void> setMonthlyIncomeGoal(int value) async {
    await setGoals(
      dailyIncomeGoal: _dailyIncomeGoal,
      monthlyIncomeGoal: value,
      dailyDeepWorkMinutes: _dailyDeepWorkMinutes,
    );
  }
}
