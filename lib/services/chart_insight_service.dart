import '../models/finance_transaction.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';

class DailyCashflowPoint {
  const DailyCashflowPoint({required this.label, required this.income, required this.expense});

  final String label;
  final int income;
  final int expense;
}

class CategorySharePoint {
  const CategorySharePoint({required this.category, required this.amount, required this.percent});

  final String category;
  final int amount;
  final double percent;
}

class ChartInsightService {
  const ChartInsightService();

  List<DailyCashflowPoint> last7DaysCashflow(FinanceRepository repository) {
    final now = DateTime.now();
    final result = <DailyCashflowPoint>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final income = repository.total(type: FinanceTransactionType.income, from: day, to: next);
      final expense = repository.total(type: FinanceTransactionType.expense, from: day, to: next);
      result.add(DailyCashflowPoint(label: PersianFormat.jalaliDate(day).substring(5), income: income, expense: expense));
    }
    return result;
  }

  List<CategorySharePoint> monthlyExpenseCategoryShares(FinanceRepository repository) {
    final start = repository.currentJalaliMonthStart();
    final end = repository.currentJalaliMonthEnd();
    final byCategory = repository.totalsByCategory(type: FinanceTransactionType.expense, from: start, to: end);
    final total = byCategory.values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return const [];
    return byCategory.entries
        .map((e) => CategorySharePoint(category: e.key, amount: e.value, percent: e.value / total))
        .take(6)
        .toList();
  }
}
