import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/services/finance_repository.dart';

/// بازتولید سناریوی «افزودن درآمد دستی» که باعث خطای
/// «_dependents.isEmpty» می‌شد: وقتی repository بعد از بستن دیالوگ
/// notifyListeners می‌دهد، widget نباید setState بعد از dispose صدا بزند.
///
/// ⚠️ نکتهٔ مهم دربارهٔ timeout (چرا قبلاً حذف شده بود):
/// عملیات واقعی دیتابیس (sqflite ffi) داخل `tester.runAsync` اجرا می‌شود.
/// در محیط fake-async تست‌های widget، Future های واقعی I/O هرگز کامل
/// نمی‌شوند و تست بی‌نهایت منتظر می‌ماند (timeout در CI).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('افزودن تراکنش و سپس بستن widget، کرش نمی‌کند', (tester) async {
    final repo = FinanceRepository();
    final key = GlobalKey<_ListenerWidgetState>();
    await tester.pumpWidget(_ListenerWidget(key: key, repo: repo));
    await tester.pump();

    // اولین افزودن: لیسنر باید یک‌بار صدا زده شود (بدون کرش).
    await tester.runAsync(() => repo.add(FinanceTransaction(
          id: 't1',
          type: FinanceTransactionType.income,
          amount: 200000,
          createdAt: DateTime.now(),
          category: 'درآمد آزاد',
        )));
    await tester.pump();
    expect(key.currentState!.rawCount, 1);

    // widget را حذف (dispose) می‌کنیم، سپس دوباره درآمد اضافه می‌کنیم.
    // اگر بعد از dispose setState صدا زده شود، همین‌جا خطای تست می‌گیریم.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await tester.runAsync(() => repo.add(FinanceTransaction(
          id: 't2',
          type: FinanceTransactionType.income,
          amount: 300000,
          createdAt: DateTime.now(),
          category: 'درآمد آزاد',
        )));
    await tester.pump();

    // widget کاملاً dispose شده؛ لیسنر هنوز فعال است (rawCount=2) ولی
    // هیچ setState بعد از dispose اتفاق نیفتاده و خطایی رخ نداده است.
    expect(key.currentState, isNull);
    // برای اطمینان: شنوندهٔ خودِ repo هنوز پاسخ می‌دهد (تست دوم هم در DB ثبت شد).
    expect(repo.transactions.length, greaterThanOrEqualTo(2));
  });
}

class _ListenerWidget extends StatefulWidget {
  const _ListenerWidget({super.key, required this.repo});
  final FinanceRepository repo;
  @override
  State<_ListenerWidget> createState() => _ListenerWidgetState();
}

class _ListenerWidgetState extends State<_ListenerWidget> {
  /// تعداد دفعات notifyListeners دریافتی (بدون وابستگی به فریم).
  int rawCount = 0;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    rawCount++;
    if (!mounted) return;
    // همان الگوی تولید: setState در post-frame callback — اگر بعد از
    // dispose صدا زده شود، flutter_test تست را مردود اعلام می‌کند.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
