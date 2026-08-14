import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/services/debt_repayment_planner.dart';
import 'package:smart_day_planner/services/work_learning_service.dart';

void main() {
  const planner = DebtRepaymentPlanner();
  final now = DateTime.now();

  RepaymentDebt _debt(String name, int amount, {int daysFromNow = 30}) {
    return RepaymentDebt(
      personName: name,
      amount: amount,
      dueAt: now.add(Duration(days: daysFromNow)),
    );
  }

  WorkProfile _profile({double hourly = 300000, double dailyMinutes = 120}) {
    final hourlyRate = hourly;
    final dailyCapacity = (dailyMinutes / 60) * hourlyRate;
    return WorkProfile(
      avgDailyWorkMinutes: dailyMinutes,
      avgHourlyRate: hourlyRate,
      dailyEarningCapacity: dailyCapacity,
      historyDays: 5,
      sampleCount: 6,
    );
  }

  group('DebtRepaymentPlanner: حل مسئلهٔ پرداخت', () {
    test('مجموع بدهی‌ها درست محاسبه می‌شود', () {
      final plan = planner.plan(
        debts: [
          _debt('علی', 20000000, daysFromNow: 30),
          _debt('محمد', 5000000, daysFromNow: 30),
          _debt('حسن', 1000000, daysFromNow: 30),
        ],
        profile: _profile(),
        now: now,
      );
      expect(plan.totalRemaining, 26000000);
    });

    test('اولویت با فوری‌ترین مهلت است، سپس مبلغ بیشتر', () {
      final plan = planner.plan(
        debts: [
          _debt('حسن', 1000000, daysFromNow: 10),
          _debt('علی', 20000000, daysFromNow: 30),
          _debt('محمد', 5000000, daysFromNow: 5),
        ],
        profile: _profile(),
        now: now,
      );
      expect(plan.priority.length, 3);
      expect(plan.priority[0].personName, 'محمد'); // فوری‌ترین (۵ روز)
      expect(plan.priority[1].personName, 'حسن'); // ۱۰ روز
      expect(plan.priority[2].personName, 'علی'); // ۳۰ روز
      expect(plan.priority[0].rank, 1);
    });

    test('درآمد لازم روزانه = مجموع / روزهای مانده', () {
      final plan = planner.plan(
        debts: [
          _debt('علی', 20000000, daysFromNow: 20),
          _debt('محمد', 5000000, daysFromNow: 20),
          _debt('حسن', 1000000, daysFromNow: 20),
        ],
        profile: _profile(hourly: 1000000),
        now: now,
      );
      // ۲۶ میلیون / ۲۰ روز = ۱.۳ میلیون در روز
      expect(plan.requiredDailyEarning, 1300000);
      expect(plan.horizonDays, 20);
    });

    test('ساعت لازم در روز با درآمد ساعتی حساب می‌شود', () {
      final plan = planner.plan(
        debts: [
          _debt('علی', 6000000, daysFromNow: 10),
        ],
        profile: _profile(hourly: 300000), // ۳۰۰ هزار در ساعت
        now: now,
      );
      // ۶ میلیون / ۱۰ روز = ۶۰۰ هزار در روز → ۲ ساعت
      expect(plan.requiredHoursPerDay, closeTo(2.0, 0.01));
      expect(plan.feasible, isTrue);
    });

    test('غیرممکن وقتی ساعت لازم از حد معقول بیشتر باشد', () {
      final plan = planner.plan(
        debts: [
          _debt('علی', 100000000, daysFromNow: 10), // ۱۰۰ میلیون در ۱۰ روز
        ],
        profile: _profile(hourly: 200000),
        now: now,
      );
      // ۱۰ میلیون در روز / ۲۰۰ هزار = ۵۰ ساعت در روز → غیرممکن
      expect(plan.feasible, isFalse);
      expect(plan.requiredHoursPerDay, greaterThan(14));
    });

    test('تاریخ پایان تخمینی با توان یادگرفته‌شده', () {
      final plan = planner.plan(
        debts: [
          _debt('علی', 1200000, daysFromNow: 30),
        ],
        profile: _profile(hourly: 300000, dailyMinutes: 120), // توان ۶۰۰ هزار/روز
        now: now,
      );
      // ۱.۲ میلیون / ۶۰۰ هزار = ۲ روز
      final expected = now.add(const Duration(days: 2));
      expect(plan.estimatedPayoffDate, isNotNull);
      expect(
        plan.estimatedPayoffDate!.difference(expected).inDays.abs() <= 1,
        isTrue,
      );
    });

    test('بدون بدهی → مجموع صفر و feasible', () {
      final plan = planner.plan(debts: const [], profile: _profile(), now: now);
      expect(plan.totalRemaining, 0);
      expect(plan.feasible, isTrue);
    });

    test('مهلت‌های متفاوت: نرخ روزانه باید قید تنگ‌کننده را بگیرد', () {
      final plan = planner.plan(
        debts: [
          _debt('علی', 2000000, daysFromNow: 10),
          _debt('محمد', 8000000, daysFromNow: 40),
        ],
        profile: _profile(hourly: 300000),
        now: now,
      );
      // تا روز ۱۰: ۲ میلیون / ۱۰ روز = ۲۰۰ هزار در روز
      // تا روز ۴۰: ۱۰ میلیون / ۴۰ روز = ۲۵۰ هزار در روز → قید تنگ‌کننده ۲۵۰ هزار
      // (روش قبلی ۱۰ میلیون / ۱۰ = ۱ میلیون می‌داد که بیش‌برآورد بود)
      expect(plan.requiredDailyEarning, 250000);
      expect(plan.horizonDays, 10);
    });
  });
}
