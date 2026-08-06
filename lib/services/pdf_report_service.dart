import '../models/finance_transaction.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';
import 'task_repository.dart';

class PdfReportService {
  const PdfReportService();

  String buildPrintableHtml({
    required TaskRepository tasks,
    required FinanceRepository finance,
    required GoalRepository goals,
  }) {
    final income = finance.incomeThisMonth();
    final expense = finance.expenseThisMonth();
    final net = finance.netThisMonth();
    final done = tasks.tasks.where((t) => t.isDone).length;
    final open = tasks.tasks.where((t) => !t.isDone).length;
    final categoryRows = finance
        .totalsByCategory(
          type: FinanceTransactionType.expense,
          from: finance.currentJalaliMonthStart(),
          to: finance.currentJalaliMonthEnd(),
        )
        .entries
        .map((e) => '<tr><td>${_escape(e.key)}</td><td>${PersianFormat.money(e.value)}</td></tr>')
        .join();

    return '''
<!doctype html>
<html lang="fa" dir="rtl">
<head><meta charset="utf-8"><title>گزارش ماه شمسی</title>
<style>body{font-family:tahoma,Arial;line-height:1.8;padding:32px;color:#222}h1{color:#51408f}table{border-collapse:collapse;width:100%;margin-top:16px}td,th{border:1px solid #ddd;padding:8px;text-align:right}.card{border:1px solid #ddd;border-radius:16px;padding:16px;margin:12px 0}</style>
</head>
<body>
<h1>گزارش ماه شمسی دستیار روزانه ایرانی</h1>
<p>تاریخ تهیه گزارش: ${PersianFormat.jalaliLong(DateTime.now())}</p>
<div class="card"><b>درآمد ماه:</b> ${PersianFormat.money(income)}<br><b>هزینه ماه:</b> ${PersianFormat.money(expense)}<br><b>خالص ماه:</b> ${PersianFormat.money(net)}</div>
<div class="card"><b>هدف درآمد ماه:</b> ${goals.monthlyIncomeGoal == 0 ? 'تنظیم نشده' : PersianFormat.money(goals.monthlyIncomeGoal)}<br><b>کارهای باز:</b> ${PersianFormat.digits(open)}<br><b>کارهای انجام‌شده:</b> ${PersianFormat.digits(done)}</div>
<h2>هزینه‌ها بر اساس دسته‌بندی</h2>
<table><tr><th>دسته‌بندی</th><th>مبلغ</th></tr>${categoryRows.isEmpty ? '<tr><td colspan="2">موردی ثبت نشده</td></tr>' : categoryRows}</table>
</body></html>
''';
  }

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
