import '../../domain/repositories/allocation_repository_port.dart';
import '../../domain/repositories/debt_repository_port.dart';
import '../../domain/repositories/finance_repository_port.dart';
import '../../domain/repositories/task_repository_port.dart';
import 'home_coordinator_v2.dart';

class HomeCoordinatorFactory {
  const HomeCoordinatorFactory();

  HomeCoordinatorV2 create({
    required TaskRepositoryPort tasks,
    required FinanceRepositoryPort finance,
    required DebtRepositoryPort debts,
    required AllocationRepositoryPort allocations,
  }) {
    return HomeCoordinatorV2(
      tasks: tasks,
      finance: finance,
      debts: debts,
      allocations: allocations,
    );
  }
}
