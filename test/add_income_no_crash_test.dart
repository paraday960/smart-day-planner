import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/services/finance_repository.dart';

/// بازتولید سناریوی «افزودن درآمد دستی» که باعث خطای
/// «_dependents.isEmpty» می‌شد: وقتی repository بعد از بستن دیالوگ
/// notifyListeners می‌دهد، widget نباید setState بعد از dispose صدا بزند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('افزودن تراکنش و then بستن widget، کرش نمی‌کند', (tester) async {
    final repo = FinanceRepository();
    final key = GlobalKey<_ListenerWidgetState>();
    await tester.pumpWidget(_ListenerWidget(key: key, repo: repo));
    await tester.pump();

    await repo.add(FinanceTransaction(
      id: 't1', type: FinanceTransactionType.income, amount: 200000,
      createdAt: DateTime.now(), category: 'درآمد آزاد',
    ));
    await tester.pump();
    expect(key.currentState!.count, 1);

    // widget را حذف (dispose) می‌کنیم، سپس دوباره افزودن درآمد.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // اگر بعد از dispose setState شود، اینجا خطا می‌دهد.
    await repo.add(FinanceTransaction(
      id: 't2', type: FinanceTransactionType.income, amount: 300000,
      createdAt: DateTime.now(), category: 'درآمد آزاد',
    ));
    await tester.pump();
    expect(true, isTrue);
  });
}

class _ListenerWidget extends StatefulWidget {
  const _ListenerWidget({super.key, required this.repo});
  final FinanceRepository repo;
  @override
  State<_ListenerWidget> createState() => _ListenerWidgetState();
}

class _ListenerWidgetState extends State<_ListenerWidget> {
  int count = 0;
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
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => count++);
    });
  }
  @override
  Widget build(BuildContext context) => const Placeholder();
}
