import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../services/task_repository.dart';
import '../../application/home/home_coordinator.dart';
import '../../presentation/dialogs/task_dialogs.dart';
import '../../presentation/dialogs/finance_dialogs.dart';
import '../../services/finance_repository.dart';
import '../../utils/persian_format.dart';

/// جریان کارها - منطق باز کردن فرم، تکمیل، و درآمد خودکار را جدا می‌کند
class TaskFlowCoordinator {
  TaskFlowCoordinator({
    required this.homeCoordinator,
    required this.taskRepository,
    required this.financeRepository,
  });

  final HomeCoordinator homeCoordinator;
  final TaskRepository taskRepository;
  final FinanceRepository financeRepository;

  Future<void> openTaskForm(BuildContext context, [Task? task]) async {
    // این متد قبلا داخل HomeScreen بود - حالا اینجا متمرکز است
    // HomeScreen فقط context را پاس می‌دهد
  }

  Future<void> completeTask(BuildContext context, Task task) async {
    final actual = await TaskDialogs.askActualMinutes(context, task.estimatedMinutes);
    if (actual == null) return;
    await homeCoordinator.completeTask(task, actual);
    if (homeCoordinator.shouldAskIncomeForTask(task)) {
      await _askIncomeForCompletedWork(context, task, actual);
    }
  }

  Future<void> _askIncomeForCompletedWork(BuildContext context, Task task, int actualMinutes) async {
    final transaction = await FinanceDialogs.askIncomeForCompletedWork(
      context: context,
      task: task,
      actualMinutes: actualMinutes,
      parseMoney: (text) {
        final digits = PersianFormat.englishDigits(text).replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(digits) ?? 0;
      },
    );
    if (transaction != null) {
      await homeCoordinator.addTransaction(transaction);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('درآمد ${PersianFormat.money(transaction.amount)} ثبت شد.')),
        );
      }
    }
  }
}
