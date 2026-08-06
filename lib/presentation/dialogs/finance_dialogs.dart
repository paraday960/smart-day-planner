import 'package:flutter/material.dart';

import '../../models/finance_transaction.dart';
import '../../models/task.dart';
import '../../utils/persian_format.dart';

class FinanceDialogs {
  const FinanceDialogs._();

  static Future<FinanceTransaction?> askIncomeForCompletedWork({
    required BuildContext context,
    required Task task,
    required int actualMinutes,
    required int Function(String value) parseMoney,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController(text: 'درآمد از ${task.title}');

    final transaction = await showDialog<FinanceTransaction>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ثبت درآمد این بازه کاری'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('برای «${task.title}» درآمدی داشتی؟ اگر بله مبلغ را وارد کن تا به درآمد فعلی اضافه شود.'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مبلغ درآمد / تومان', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'توضیح', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('درآمد نداشت')),
            FilledButton(
              onPressed: () {
                final amount = parseMoney(amountController.text);
                if (amount <= 0) return;
                Navigator.pop(
                  context,
                  FinanceTransaction(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    type: FinanceTransactionType.income,
                    amount: amount,
                    createdAt: DateTime.now(),
                    note: noteController.text.trim(),
                    category: task.category,
                    taskId: task.id,
                    minutesWorked: actualMinutes,
                  ),
                );
              },
              child: const Text('اضافه به درآمد'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    noteController.dispose();
    return transaction;
  }

  static Future<FinanceTransaction?> openTransactionDialog({
    required BuildContext context,
    required FinanceTransactionType type,
    required int Function(String value) parseMoney,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final categoryController = TextEditingController(text: type == FinanceTransactionType.income ? 'درآمد آزاد' : 'هزینه شخصی');

    final transaction = await showDialog<FinanceTransaction>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ثبت ${type.faLabel}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مبلغ / تومان', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'دسته‌بندی', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'توضیح اختیاری', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final amount = parseMoney(amountController.text);
                if (amount <= 0) return;
                Navigator.pop(
                  context,
                  FinanceTransaction(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    type: type,
                    amount: amount,
                    createdAt: DateTime.now(),
                    note: noteController.text.trim(),
                    category: categoryController.text.trim().isEmpty ? 'عمومی' : categoryController.text.trim(),
                  ),
                );
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    noteController.dispose();
    categoryController.dispose();
    return transaction;
  }

  static String formatAmount(int amount) => PersianFormat.money(amount);
}
