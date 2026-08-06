import 'package:flutter/material.dart';

import '../../application/actions/goal_actions_controller.dart';
import '../../services/goal_repository.dart';
import '../../utils/persian_format.dart';

class GoalDialogs {
  const GoalDialogs._();

  static Future<GoalInputData?> goals({
    required BuildContext context,
    required GoalRepository repository,
    required int Function(String value) parseMoney,
  }) async {
    final dailyController = TextEditingController(text: PersianFormat.digits(repository.dailyIncomeGoal));
    final monthlyController = TextEditingController(text: PersianFormat.digits(repository.monthlyIncomeGoal));
    final deepWorkController = TextEditingController(text: PersianFormat.digits(repository.dailyDeepWorkMinutes));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('هدف‌های هوشمند'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dailyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'هدف درآمد روزانه / تومان', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthlyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'هدف درآمد ماه شمسی / تومان', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deepWorkController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'هدف کار عمیق روزانه / دقیقه', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
          ],
        ),
      ),
    );

    final input = saved == true
        ? GoalInputData(
            dailyIncomeGoal: parseMoney(dailyController.text),
            monthlyIncomeGoal: parseMoney(monthlyController.text),
            dailyDeepWorkMinutes: int.tryParse(PersianFormat.englishDigits(deepWorkController.text)) ?? 120,
          )
        : null;
    dailyController.dispose();
    monthlyController.dispose();
    deepWorkController.dispose();
    return input;
  }
}
