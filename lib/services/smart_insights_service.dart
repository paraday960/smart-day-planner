import 'dart:math';

import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';
import 'smart_planner.dart';

class SmartInsightsService {
  const SmartInsightsService({SmartPlanner planner = const SmartPlanner()}) : _planner = planner;

  final SmartPlanner _planner;

  List<String> decisionInsights({
    required List<Task> tasks,
    required FinanceRepository finance,
    required GoalRepository goals,
  }) {
    final result = <String>[];
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) return ['همه کارها انجام شده‌اند؛ برای ادامه روز می‌توانی استراحت یا برنامه فردا را آماده کنی.'];

    final bestValueTask = bestIncomeAwareTask(tasks: tasks, finance: finance);
    if (bestValueTask != null) {
      final rate = expectedHourlyRate(bestValueTask, finance).round();
      if (rate > 0) {
        result.add('از نظر ارزش زمان، «${bestValueTask.title}» گزینه خوبی است؛ درآمد احتمالی هر ساعت برای این دسته حدود ${PersianFormat.money(rate)} است.');
      }
    }

    final dailyGap = goals.dailyIncomeGoal - finance.incomeToday();
    if (goals.dailyIncomeGoal > 0) {
      if (dailyGap <= 0) {
        result.add('هدف درآمد امروزت کامل شده؛ اگر انرژی داری روی کارهای مهم ولی غیرفوری تمرکز کن.');
      } else {
        final avgRate = finance.averageHourlyRate();
        if (avgRate > 0) {
          final neededMinutes = (dailyGap / avgRate * 60).ceil();
          result.add('برای رسیدن به هدف درآمد امروز، حدود ${PersianFormat.money(dailyGap)} دیگر نیاز داری؛ با میانگین فعلی یعنی حدود ${PersianFormat.minutes(neededMinutes)} کار درآمدزا.');
        } else {
          result.add('برای رسیدن به هدف درآمد امروز، هنوز ${PersianFormat.money(dailyGap)} فاصله داری.');
        }
      }
    }

    final heavyOpen = open.where((t) => t.energy == EnergyLevel.high).length;
    final nowHour = DateTime.now().hour;
    if (heavyOpen > 0 && nowHour >= 18) {
      result.add('${PersianFormat.digits(heavyOpen)} کار سنگین باز داری؛ اگر خسته‌ای فقط برنامه‌ریزی کن و اجرای اصلی را به صبح منتقل کن.');
    }

    return result.take(4).toList();
  }

  Task? bestIncomeAwareTask({required List<Task> tasks, required FinanceRepository finance}) {
    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) return null;

    open.sort((a, b) {
      final aScore = _planner.priorityScore(a) + financialScore(a, finance);
      final bScore = _planner.priorityScore(b) + financialScore(b, finance);
      return bScore.compareTo(aScore);
    });
    return open.first;
  }

  int financialScore(Task task, FinanceRepository finance) {
    final rate = expectedHourlyRate(task, finance);
    if (rate <= 0) return 0;
    if (rate >= 2000000) return 45;
    if (rate >= 1000000) return 35;
    if (rate >= 500000) return 25;
    if (rate >= 200000) return 15;
    return 8;
  }

  double expectedHourlyRate(Task task, FinanceRepository finance) {
    final related = finance.transactions.where((t) {
      return t.type == FinanceTransactionType.income &&
          t.hourlyRate != null &&
          (t.category == task.category || _hasSharedWord(t.note, task.title));
    }).toList();

    if (related.isNotEmpty) {
      return related.map((t) => t.hourlyRate!).reduce((a, b) => a + b) / related.length;
    }

    return finance.averageHourlyRate();
  }

  List<String> weeklyPerformance({required List<Task> tasks, required FinanceRepository finance}) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday == DateTime.saturday ? 0 : (now.weekday + 1) % 7));
    final doneThisWeek = tasks.where((t) => t.isDone && t.completedAt != null && !t.completedAt!.isBefore(weekStart)).toList();
    final openOverdue = tasks.where((t) => t.isOverdue).length;
    final result = <String>[];

    result.add('این هفته ${PersianFormat.digits(doneThisWeek.length)} کار را کامل کرده‌ای.');

    final withActual = doneThisWeek.where((t) => t.actualMinutes != null && t.actualMinutes! > 0).toList();
    if (withActual.isNotEmpty) {
      final estimated = withActual.fold<int>(0, (sum, t) => sum + t.estimatedMinutes);
      final actual = withActual.fold<int>(0, (sum, t) => sum + t.actualMinutes!);
      if (actual > estimated * 1.2) {
        result.add('تخمین زمانت خوش‌بینانه بوده؛ بهتر است برای کارهای مشابه حدود ${PersianFormat.digits(((actual / max(1, estimated) - 1) * 100).round())}٪ زمان اضافه در نظر بگیری.');
      } else if (actual < estimated * 0.8) {
        result.add('این هفته معمولاً سریع‌تر از تخمینت کارها را تمام کرده‌ای؛ برنامه روزانه می‌تواند کمی فشرده‌تر شود.');
      } else {
        result.add('تخمین زمانت این هفته نسبتاً دقیق بوده است.');
      }
    }

    if (openOverdue > 0) {
      result.add('${PersianFormat.digits(openOverdue)} کار عقب‌افتاده داری؛ قبل از شروع کار جدید، یکی از آن‌ها را ببند.');
    }

    final weekIncome = finance.incomeThisWeek();
    if (weekIncome > 0) {
      result.add('درآمد هفته جاری ${PersianFormat.money(weekIncome)} است.');
    }

    return result.take(5).toList();
  }

  bool _hasSharedWord(String a, String b) {
    final aw = a.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final bw = b.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    return aw.intersection(bw).isNotEmpty;
  }
}
