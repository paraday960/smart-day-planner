import '../models/finance_transaction.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';

class ExportService {
  const ExportService();

  String tasksCsv(List<Task> tasks) {
    final rows = <List<String>>[
      ['عنوان', 'دسته‌بندی', 'وضعیت', 'اهمیت', 'انرژی', 'زمان تخمینی دقیقه', 'زمان واقعی دقیقه', 'تاریخ ایجاد', 'مهلت انجام', 'توضیحات'],
      ...tasks.map((t) => [
            t.title,
            t.category,
            t.isDone ? 'انجام‌شده' : 'باز',
            t.importance.toString(),
            t.energy.faLabel,
            t.estimatedMinutes.toString(),
            t.actualMinutes?.toString() ?? '',
            PersianFormat.jalaliDateTime(t.createdAt),
            t.dueAt == null ? '' : PersianFormat.jalaliDateTime(t.dueAt!),
            t.notes,
          ]),
    ];
    return _toCsv(rows);
  }

  String transactionsCsv(List<FinanceTransaction> transactions) {
    final rows = <List<String>>[
      ['نوع', 'مبلغ تومان', 'دسته‌بندی', 'تاریخ', 'توضیح', 'دقیقه کار', 'درآمد ساعتی'],
      ...transactions.map((t) => [
            t.type.faLabel,
            t.amount.toString(),
            t.category,
            PersianFormat.jalaliDateTime(t.createdAt),
            t.note,
            t.minutesWorked?.toString() ?? '',
            t.hourlyRate?.round().toString() ?? '',
          ]),
    ];
    return _toCsv(rows);
  }

  String monthlyReport({
    required List<Task> tasks,
    required FinanceRepository financeRepository,
    required GoalRepository goalRepository,
  }) {
    final income = financeRepository.incomeThisMonth();
    final expense = financeRepository.expenseThisMonth();
    final net = financeRepository.netThisMonth();
    final done = tasks.where((t) => t.isDone).length;
    final open = tasks.where((t) => !t.isDone).length;
    final hourly = financeRepository.averageHourlyRate().round();
    final monthGoal = goalRepository.monthlyIncomeGoal;
    final progress = monthGoal <= 0 ? 0 : (income / monthGoal * 100).clamp(0, 100).round();

    final buffer = StringBuffer()
      ..writeln('گزارش ماه شمسی دستیار روزانه ایرانی')
      ..writeln('تاریخ تهیه گزارش: ${PersianFormat.jalaliLong(DateTime.now())}')
      ..writeln('')
      ..writeln('خلاصه مالی')
      ..writeln('- درآمد ماه: ${PersianFormat.money(income)}')
      ..writeln('- هزینه ماه: ${PersianFormat.money(expense)}')
      ..writeln('- خالص ماه: ${PersianFormat.money(net)}')
      ..writeln('- میانگین درآمد ساعتی: ${hourly == 0 ? 'نامشخص' : PersianFormat.hourRate(hourly)}')
      ..writeln('- هدف درآمد ماه: ${monthGoal == 0 ? 'تنظیم نشده' : PersianFormat.money(monthGoal)}')
      ..writeln('- پیشرفت هدف ماه: ${PersianFormat.digits(progress)}٪')
      ..writeln('')
      ..writeln('خلاصه کارها')
      ..writeln('- کارهای انجام‌شده: ${PersianFormat.digits(done)}')
      ..writeln('- کارهای باز: ${PersianFormat.digits(open)}')
      ..writeln('')
      ..writeln('دسته‌بندی درآمد ماه');

    final incomeByCategory = financeRepository.totalsByCategory(
      type: FinanceTransactionType.income,
      from: financeRepository.currentJalaliMonthStart(),
      to: financeRepository.currentJalaliMonthEnd(),
    );
    if (incomeByCategory.isEmpty) {
      buffer.writeln('- موردی ثبت نشده');
    } else {
      for (final entry in incomeByCategory.entries) {
        buffer.writeln('- ${entry.key}: ${PersianFormat.money(entry.value)}');
      }
    }

    buffer
      ..writeln('')
      ..writeln('دسته‌بندی هزینه ماه');

    final expenseByCategory = financeRepository.totalsByCategory(
      type: FinanceTransactionType.expense,
      from: financeRepository.currentJalaliMonthStart(),
      to: financeRepository.currentJalaliMonthEnd(),
    );
    if (expenseByCategory.isEmpty) {
      buffer.writeln('- موردی ثبت نشده');
    } else {
      for (final entry in expenseByCategory.entries) {
        buffer.writeln('- ${entry.key}: ${PersianFormat.money(entry.value)}');
      }
    }

    return buffer.toString();
  }

  String _toCsv(List<List<String>> rows) {
    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
