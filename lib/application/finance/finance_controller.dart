import '../../models/finance_transaction.dart';
import '../../services/finance_repository.dart';
import 'finance_summary.dart';

class FinanceController {
  const FinanceController();

  FinanceSummary buildSummary(FinanceRepository repository) {
    final monthStart = repository.currentJalaliMonthStart();
    final monthEnd = repository.currentJalaliMonthEnd();
    return FinanceSummary(
      incomeToday: repository.incomeToday(),
      expenseToday: repository.expenseToday(),
      incomeWeek: repository.incomeThisWeek(),
      expenseWeek: repository.expenseThisWeek(),
      incomeMonth: repository.incomeThisMonth(),
      expenseMonth: repository.expenseThisMonth(),
      netMonth: repository.netThisMonth(),
      averageHourlyRate: repository.averageHourlyRate().round(),
      incomeByCategory: repository.totalsByCategory(
        type: FinanceTransactionType.income,
        from: monthStart,
        to: monthEnd,
      ),
      expenseByCategory: repository.totalsByCategory(
        type: FinanceTransactionType.expense,
        from: monthStart,
        to: monthEnd,
      ),
    );
  }
}
