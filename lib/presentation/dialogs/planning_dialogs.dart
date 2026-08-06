import 'package:flutter/material.dart';

import '../../models/debt_item.dart';
import '../../utils/persian_format.dart';

class PlannedExpenseInput {
  const PlannedExpenseInput({required this.title, required this.amount, required this.days});

  final String title;
  final int amount;
  final int days;
}

class DebtInput {
  const DebtInput({required this.type, required this.personName, required this.amount, required this.days});

  final DebtType type;
  final String personName;
  final int amount;
  final int days;
}

class AllocationInput {
  const AllocationInput({required this.amount});

  final int amount;
}

class CategoryBudgetInput {
  const CategoryBudgetInput({required this.category, required this.monthlyLimit});

  final String category;
  final int monthlyLimit;
}

class AvailabilityInput {
  const AvailabilityInput({
    required this.startHour,
    required this.endHour,
    required this.breakMinutesPerHour,
    required this.isFridayOff,
  });

  final int startHour;
  final int endHour;
  final int breakMinutesPerHour;
  final bool isFridayOff;
}

class PlanningDialogs {
  const PlanningDialogs._();

  static Future<PlannedExpenseInput?> plannedExpense({
    required BuildContext context,
    required int Function(String value) parseMoney,
  }) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final daysController = TextEditingController(text: PersianFormat.digits(7));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('هزینه برنامه‌ریزی‌شده'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'عنوان، مثلاً بیرون رفتن', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ لازم / تومان', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'چند روز دیگر؟', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
          ],
        ),
      ),
    );

    final result = saved == true
        ? PlannedExpenseInput(
            title: titleController.text.trim().isEmpty ? 'هزینه برنامه‌ریزی‌شده' : titleController.text.trim(),
            amount: parseMoney(amountController.text),
            days: int.tryParse(PersianFormat.englishDigits(daysController.text)) ?? 7,
          )
        : null;
    titleController.dispose();
    amountController.dispose();
    daysController.dispose();
    return result;
  }

  static Future<DebtInput?> debt({
    required BuildContext context,
    required int Function(String value) parseMoney,
  }) async {
    final personController = TextEditingController();
    final amountController = TextEditingController();
    final daysController = TextEditingController(text: PersianFormat.digits(2));
    var type = DebtType.debt;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ثبت بدهی یا طلب'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<DebtType>(
                    segments: DebtType.values.map((e) => ButtonSegment(value: e, label: Text(e.faLabel))).toList(),
                    selected: {type},
                    onSelectionChanged: (value) => setDialogState(() => type = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: personController,
                    decoration: const InputDecoration(labelText: 'نام شخص، مثلاً ممد', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مبلغ / تومان', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'چند روز دیگر؟', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ثبت')),
            ],
          ),
        ),
      ),
    );

    final result = saved == true
        ? DebtInput(
            type: type,
            personName: personController.text.trim().isEmpty ? 'نامشخص' : personController.text.trim(),
            amount: parseMoney(amountController.text),
            days: int.tryParse(PersianFormat.englishDigits(daysController.text)) ?? 2,
          )
        : null;
    personController.dispose();
    amountController.dispose();
    daysController.dispose();
    return result;
  }

  static Future<int?> amount({
    required BuildContext context,
    required String title,
    required int Function(String value) parseMoney,
    String initial = '',
  }) async {
    final amountController = TextEditingController(text: initial);
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'مبلغ / تومان', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(context, parseMoney(amountController.text)), child: const Text('ثبت')),
          ],
        ),
      ),
    );
    amountController.dispose();
    return amount;
  }

  static Future<CategoryBudgetInput?> categoryBudget({
    required BuildContext context,
    required int Function(String value) parseMoney,
  }) async {
    final categoryController = TextEditingController();
    final limitController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بودجه ماهانه دسته‌بندی'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'دسته‌بندی، مثلاً تفریح', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'سقف ماهانه / تومان', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    final result = saved == true && categoryController.text.trim().isNotEmpty
        ? CategoryBudgetInput(category: categoryController.text.trim(), monthlyLimit: parseMoney(limitController.text))
        : null;
    categoryController.dispose();
    limitController.dispose();
    return result;
  }

  static Future<AvailabilityInput?> availability({
    required BuildContext context,
    required int startHour,
    required int endHour,
    required int breakMinutesPerHour,
    required bool fridayOff,
  }) async {
    final startController = TextEditingController(text: PersianFormat.digits(startHour));
    final endController = TextEditingController(text: PersianFormat.digits(endHour));
    final breakController = TextEditingController(text: PersianFormat.digits(breakMinutesPerHour));
    var isFridayOff = fridayOff;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('محدودیت زمانی و پنجره کاری'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: startController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'شروع کار روزانه / ساعت', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: endController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'پایان کار روزانه / ساعت', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: breakController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'استراحت به ازای هر ساعت / دقیقه', border: OutlineInputBorder())),
                CheckboxListTile(
                  value: isFridayOff,
                  onChanged: (value) => setDialogState(() => isFridayOff = value ?? true),
                  title: const Text('جمعه روز غیرکاری باشد'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
            ],
          ),
        ),
      ),
    );

    final result = saved == true
        ? AvailabilityInput(
            startHour: int.tryParse(PersianFormat.englishDigits(startController.text)) ?? 9,
            endHour: int.tryParse(PersianFormat.englishDigits(endController.text)) ?? 18,
            breakMinutesPerHour: int.tryParse(PersianFormat.englishDigits(breakController.text)) ?? 10,
            isFridayOff: isFridayOff,
          )
        : null;
    startController.dispose();
    endController.dispose();
    breakController.dispose();
    return result;
  }
}
