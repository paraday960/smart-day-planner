import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/finance_transaction.dart';
import '../utils/persian_format.dart';
import 'finance_repository.dart';
import 'goal_repository.dart';
import 'task_repository.dart';

class RealPdfReportService {
  const RealPdfReportService();

  Future<Uint8List> buildMonthlyPdf({
    required TaskRepository tasks,
    required FinanceRepository finance,
    required GoalRepository goals,
  }) async {
    final fontData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
    final vazirmatn = pw.Font.ttf(fontData);
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: vazirmatn, bold: vazirmatn));
    final income = finance.incomeThisMonth();
    final expense = finance.expenseThisMonth();
    final net = finance.netThisMonth();
    final done = tasks.tasks.where((t) => t.isDone).length;
    final open = tasks.tasks.where((t) => !t.isDone).length;
    final expenseCategories = finance.totalsByCategory(
      type: FinanceTransactionType.expense,
      from: finance.currentJalaliMonthStart(),
      to: finance.currentJalaliMonthEnd(),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('گزارش ماه شمسی دستیار روزانه ایرانی')),
          pw.Text('تاریخ گزارش: ${PersianFormat.jalaliLong(DateTime.now())}'),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('درآمد ماه: ${PersianFormat.money(income)}'),
                pw.Text('هزینه ماه: ${PersianFormat.money(expense)}'),
                pw.Text('خالص ماه: ${PersianFormat.money(net)}'),
                pw.Text('هدف ماه: ${goals.monthlyIncomeGoal == 0 ? 'تنظیم نشده' : PersianFormat.money(goals.monthlyIncomeGoal)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('کارهای باز: ${PersianFormat.digits(open)}'),
          pw.Text('کارهای انجام‌شده: ${PersianFormat.digits(done)}'),
          pw.SizedBox(height: 16),
          pw.Text('هزینه‌ها بر اساس دسته‌بندی'),
          pw.Table.fromTextArray(
            headers: ['دسته‌بندی', 'مبلغ'],
            data: expenseCategories.entries
                .map((e) => [e.key, PersianFormat.money(e.value)])
                .toList(),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
