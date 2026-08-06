import '../../models/finance_transaction.dart';

class FinanceSummary {
  const FinanceSummary({
    required this.incomeToday,
    required this.expenseToday,
    required this.incomeWeek,
    required this.expenseWeek,
    required this.incomeMonth,
    required this.expenseMonth,
    required this.netMonth,
    required this.averageHourlyRate,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  final int incomeToday;
  final int expenseToday;
  final int incomeWeek;
  final int expenseWeek;
  final int incomeMonth;
  final int expenseMonth;
  final int netMonth;
  final int averageHourlyRate;
  final Map<String, int> incomeByCategory;
  final Map<String, int> expenseByCategory;

  int totalFor(FinanceTransactionType type) {
    return type == FinanceTransactionType.income ? incomeMonth : expenseMonth;
  }
}
