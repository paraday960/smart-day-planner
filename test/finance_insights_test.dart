import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/services/finance_insights_service.dart';

FinanceTransaction _tx({
  required String id,
  required FinanceTransactionType type,
  required int amount,
  required DateTime createdAt,
  String category = 'عمومی',
  int? minutesWorked,
}) {
  return FinanceTransaction(
    id: id,
    type: type,
    amount: amount,
    createdAt: createdAt,
    category: category,
    minutesWorked: minutesWorked,
  );
}

void main() {
  const insights = FinanceInsightsService();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('expenseAnomalies', () {
    test('دسته‌ای که هزینه‌اش بیش از ۱.۵ برابر شده شناسایی می‌شود', () {
      final txs = [
        // ۳۰ روز اخیر: خوراک ۴۰۰ هزار
        _tx(
            id: 'a1',
            type: FinanceTransactionType.expense,
            amount: 400000,
            createdAt: today.subtract(const Duration(days: 2)),
            category: 'خوراک'),
        // قبلی: خوراک ۱۰۰ هزار
        _tx(
            id: 'a2',
            type: FinanceTransactionType.expense,
            amount: 100000,
            createdAt: today.subtract(const Duration(days: 40)),
            category: 'خوراک'),
        // دستهٔ عادی
        _tx(
            id: 'a3',
            type: FinanceTransactionType.expense,
            amount: 300000,
            createdAt: today.subtract(const Duration(days: 3)),
            category: 'رفت‌وآمد'),
        _tx(
            id: 'a4',
            type: FinanceTransactionType.expense,
            amount: 350000,
            createdAt: today.subtract(const Duration(days: 38)),
            category: 'رفت‌وآمد'),
      ];

      final anomalies = insights.expenseAnomalies(txs);

      expect(anomalies.length, 1);
      expect(anomalies.single.category, 'خوراک');
      expect(anomalies.single.currentAmount, 400000);
      expect(anomalies.single.previousAmount, 100000);
    });

    test('بدون داده یا بدون جهش → خالی', () {
      expect(insights.expenseAnomalies(const []), isEmpty);

      final flat = [
        _tx(
            id: 'b1',
            type: FinanceTransactionType.expense,
            amount: 100000,
            createdAt: today.subtract(const Duration(days: 2)),
            category: 'خوراک'),
        _tx(
            id: 'b2',
            type: FinanceTransactionType.expense,
            amount: 120000,
            createdAt: today.subtract(const Duration(days: 40)),
            category: 'خوراک'),
      ];
      expect(insights.expenseAnomalies(flat), isEmpty);
    });

    test('دستهٔ بدون سابقهٔ قبلی نادیده گرفته می‌شود', () {
      final txs = [
        _tx(
            id: 'c1',
            type: FinanceTransactionType.expense,
            amount: 500000,
            createdAt: today.subtract(const Duration(days: 1)),
            category: 'سفر'),
      ];
      expect(insights.expenseAnomalies(txs), isEmpty);
    });
  });

  group('advice', () {
    test('نسبت خرج به درآمد بالا → توصیهٔ کاهش هزینه', () {
      final txs = [
        _tx(
            id: 'd1',
            type: FinanceTransactionType.income,
            amount: 1000000,
            createdAt: today.subtract(const Duration(days: 1))),
        _tx(
            id: 'd2',
            type: FinanceTransactionType.expense,
            amount: 950000,
            createdAt: today.subtract(const Duration(days: 1))),
      ];
      final advice = insights.advice(txs);
      expect(advice.join('\n'), contains('خرج شده'));
    });

    test('میانگین درآمد ساعتی از کارهای با زمان واقعی محاسبه می‌شود', () {
      final txs = [
        _tx(
            id: 'e1',
            type: FinanceTransactionType.income,
            amount: 600000,
            createdAt: today.subtract(const Duration(days: 2)),
            minutesWorked: 60),
        _tx(
            id: 'e2',
            type: FinanceTransactionType.income,
            amount: 900000,
            createdAt: today.subtract(const Duration(days: 4)),
            minutesWorked: 90),
      ];
      final advice = insights.advice(txs);
      expect(advice.join('\n'), contains('درآمد ساعتی'));
    });

    test('بدون تراکنش → خالی', () {
      expect(insights.advice(const []), isEmpty);
    });
  });

  group('riskFrom', () {
    test('هزینه بدون درآمد → ریسک', () {
      final txs = [
        _tx(
            id: 'f1',
            type: FinanceTransactionType.expense,
            amount: 500000,
            createdAt: today.subtract(const Duration(days: 1))),
      ];
      final risk = insights.riskFrom(txs);
      expect(risk, isNotNull);
      expect(risk, contains('هزینه'));
    });

    test('درآمد بیشتر از هزینه → بدون ریسک', () {
      final txs = [
        _tx(
            id: 'g1',
            type: FinanceTransactionType.income,
            amount: 2000000,
            createdAt: today.subtract(const Duration(days: 1))),
        _tx(
            id: 'g2',
            type: FinanceTransactionType.expense,
            amount: 500000,
            createdAt: today.subtract(const Duration(days: 1))),
      ];
      expect(insights.riskFrom(txs), isNull);
    });
  });
}
