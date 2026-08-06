import '../../models/finance_transaction.dart';
import '../../models/task.dart';
import '../../services/finance_assistant.dart';
import '../../domain/repositories/finance_repository_port.dart';

class FinanceActionsController {
  const FinanceActionsController({FinanceAssistant assistant = const FinanceAssistant()}) : _assistant = assistant;

  final FinanceAssistant _assistant;

  bool shouldAskIncomeForTask(Task task) => _assistant.isWorkTask(task);

  Future<void> addTransaction({
    required FinanceRepositoryPort repository,
    required FinanceTransaction transaction,
  }) async {
    await repository.add(transaction);
  }

  Future<void> addIncomeForCompletedTask({
    required FinanceRepositoryPort repository,
    required Task task,
    required int amount,
    required int actualMinutes,
    String? note,
  }) async {
    await repository.add(
      FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: FinanceTransactionType.income,
        amount: amount,
        createdAt: DateTime.now(),
        note: note ?? 'درآمد از ${task.title}',
        category: task.category,
        taskId: task.id,
        minutesWorked: actualMinutes,
      ),
    );
  }
}
