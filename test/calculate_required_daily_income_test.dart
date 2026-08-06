import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/domain/usecases/calculate_required_daily_income.dart';

void main() {
  group('CalculateRequiredDailyIncome', () {
    test('calculates daily income based on remaining amount and days left', () {
      final usecase = CalculateRequiredDailyIncome();
      final result = usecase(
        targetAmount: 1000000,
        savedAmount: 200000,
        dueAt: DateTime(2026, 1, 4),
        now: DateTime(2026, 1, 1),
      );

      expect(result.remainingAmount, 800000);
      expect(result.daysLeft, 4);
      expect(result.requiredDailyIncome, 200000);
    });

    test('uses at least one day to avoid division by zero', () {
      final usecase = CalculateRequiredDailyIncome();
      final result = usecase(
        targetAmount: 500000,
        savedAmount: 0,
        dueAt: DateTime(2026, 1, 1),
        now: DateTime(2026, 1, 3),
      );

      expect(result.daysLeft, 1);
      expect(result.requiredDailyIncome, 500000);
    });
  });
}
