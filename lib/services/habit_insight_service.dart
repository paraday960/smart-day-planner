import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';

class HabitInsightService {
  const HabitInsightService();

  List<String> insights({required List<Task> tasks, required FinanceRepository financeRepository}) {
    final result = <String>[];
    result.addAll(_timeEstimationInsights(tasks));
    result.addAll(_incomePatternInsights(financeRepository));
    if (result.isEmpty) {
      result.add('برای تحلیل عادت‌ها، چند روز کار، درآمد، هزینه و زمان واقعی انجام کارها را ثبت کن.');
    }
    return result.take(5).toList();
  }

  List<String> _timeEstimationInsights(List<Task> tasks) {
    final done = tasks.where((t) => t.isDone && t.actualMinutes != null && t.actualMinutes! > 0).toList();
    if (done.length < 3) return const [];

    final byCategory = <String, List<Task>>{};
    for (final task in done) {
      byCategory.putIfAbsent(task.category, () => []).add(task);
    }

    final result = <String>[];
    for (final entry in byCategory.entries) {
      if (entry.value.length < 2) continue;
      final estimated = entry.value.fold<int>(0, (sum, t) => sum + t.estimatedMinutes);
      final actual = entry.value.fold<int>(0, (sum, t) => sum + (t.actualMinutes ?? 0));
      if (estimated <= 0) continue;
      final ratio = actual / estimated;
      if (ratio >= 1.25) {
        result.add('در دسته «${entry.key}» معمولاً ${PersianFormat.digits(((ratio - 1) * 100).round())}٪ بیشتر از تخمینت زمان می‌گذاری.');
      } else if (ratio <= 0.75) {
        result.add('در دسته «${entry.key}» معمولاً سریع‌تر از تخمینت کارها را تمام می‌کنی.');
      }
    }
    return result;
  }

  List<String> _incomePatternInsights(FinanceRepository financeRepository) {
    final incomes = financeRepository.transactions.where((t) => t.type == FinanceTransactionType.income).toList();
    if (incomes.length < 5) return const [];

    final byWeekday = <int, int>{};
    for (final income in incomes) {
      byWeekday.update(income.createdAt.weekday, (value) => value + income.amount, ifAbsent: () => income.amount);
    }
    if (byWeekday.length < 2) return const [];

    final best = byWeekday.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final worst = byWeekday.entries.reduce((a, b) => a.value <= b.value ? a : b);
    return [
      'تا الان بیشترین درآمد ثبت‌شده‌ات در روز ${_weekdayName(best.key)} بوده و کمترین در ${_weekdayName(worst.key)}. برای تعهدهای مهم، روی روزهای پربازده‌تر حساب کن.',
    ];
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یکشنبه';
      case DateTime.monday:
        return 'دوشنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنجشنبه';
      case DateTime.friday:
        return 'جمعه';
    }
    return '';
  }
}
