import '../../domain/repositories/allocation_repository_port.dart';
import '../../domain/repositories/availability_repository_port.dart';
import '../../domain/repositories/category_budget_repository_port.dart';
import '../../domain/repositories/debt_repository_port.dart';
import '../../domain/repositories/finance_repository_port.dart';
import '../../domain/repositories/goal_repository_port.dart';
import '../../domain/repositories/planned_expense_repository_port.dart';
import '../../domain/repositories/task_repository_port.dart';
import '../../models/debt_item.dart';
import '../../models/finance_transaction.dart';
import '../../models/money_allocation.dart';
import '../../models/planned_expense_goal.dart';
import '../../models/task.dart';
import '../../models/work_time_settings.dart';
import '../../presentation/dialogs/goal_dialogs.dart';
import '../../presentation/dialogs/planning_dialogs.dart';
import '../../domain/services/notification_service_port.dart';
import '../../services/security_service.dart';
import '../actions/allocation_actions_controller.dart';
import '../actions/backup_actions_controller.dart';
import '../actions/debt_actions_controller.dart';
import '../finance/finance_actions_controller.dart';
import '../actions/goal_actions_controller.dart';
import '../actions/report_actions_controller.dart';
import '../actions/security_actions_controller.dart';
import '../tasks/task_actions_controller.dart';

class HomeCoordinator {
  const HomeCoordinator({
    required this.taskRepository,
    required this.financeRepository,
    required this.goalRepository,
    required this.plannedExpenseRepository,
    required this.debtRepository,
    required this.allocationRepository,
    required this.categoryBudgetRepository,
    required this.availabilityRepository,
    required this.notificationService,
    required this.securityService,
    required this.taskActions,
    required this.financeActions,
    required this.debtActions,
    required this.allocationActions,
    required this.goalActions,
    required this.backupActions,
    required this.securityActions,
    required this.reportActions,
  });

  final TaskRepositoryPort taskRepository;
  final FinanceRepositoryPort financeRepository;
  final GoalRepositoryPort goalRepository;
  final PlannedExpenseRepositoryPort plannedExpenseRepository;
  final DebtRepositoryPort debtRepository;
  final AllocationRepositoryPort allocationRepository;
  final CategoryBudgetRepositoryPort categoryBudgetRepository;
  final AvailabilityRepositoryPort availabilityRepository;
  final NotificationServicePort notificationService;
  final SecurityService securityService;

  final TaskActionsController taskActions;
  final FinanceActionsController financeActions;
  final DebtActionsController debtActions;
  final AllocationActionsController allocationActions;
  final GoalActionsController goalActions;
  final BackupActionsController backupActions;
  final SecurityActionsController securityActions;
  final ReportActionsController reportActions;

  Future<void> saveTask(Task task, {required bool isNew}) {
    return taskActions.saveTask(
      repository: taskRepository,
      notificationService: notificationService,
      task: task,
      isNew: isNew,
    );
  }

  Future<void> completeTask(Task task, int actualMinutes) {
    return taskActions.completeTask(
      repository: taskRepository,
      notificationService: notificationService,
      task: task,
      actualMinutes: actualMinutes,
    );
  }

  Future<void> reopenTask(Task task) {
    return taskActions.reopenTask(
      repository: taskRepository,
      notificationService: notificationService,
      task: task,
    );
  }

  Future<void> deleteTask(Task task) {
    return taskActions.deleteTask(
      repository: taskRepository,
      notificationService: notificationService,
      task: task,
    );
  }

  bool shouldAskIncomeForTask(Task task) => financeActions.shouldAskIncomeForTask(task);

  Future<void> addTransaction(FinanceTransaction transaction) {
    return financeActions.addTransaction(repository: financeRepository, transaction: transaction);
  }

  Future<void> saveGoals(GoalInputData input) {
    return goalActions.saveGoals(repository: goalRepository, input: input);
  }

  Future<void> addPlannedExpense(PlannedExpenseInput input) {
    if (input.amount <= 0) return Future.value();
    return plannedExpenseRepository.add(
      PlannedExpenseGoal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: input.title,
        targetAmount: input.amount,
        dueAt: DateTime.now().add(Duration(days: input.days.clamp(1, 3650).toInt())),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> addDebt(DebtInput input) {
    if (input.amount <= 0) return Future.value();
    return debtActions.addDebt(
      repository: debtRepository,
      item: DebtItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: input.type,
        personName: input.personName,
        amount: input.amount,
        dueAt: DateTime.now().add(Duration(days: input.days.clamp(1, 3650).toInt())),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> settleDebt(DebtItem item, int amount) {
    return debtActions.settleAmount(
      debtRepository: debtRepository,
      financeRepository: financeRepository,
      item: item,
      amount: amount,
    );
  }

  Future<void> allocate({
    required AllocationTargetType targetType,
    required String targetId,
    required int amount,
    required String note,
  }) {
    return allocationActions.allocate(
      repository: allocationRepository,
      targetType: targetType,
      targetId: targetId,
      amount: amount,
      note: note,
    );
  }

  Future<void> saveCategoryBudget(CategoryBudgetInput input) {
    return categoryBudgetRepository.upsert(input.category, input.monthlyLimit);
  }

  Future<void> saveAvailability(AvailabilityInput input) {
    return availabilityRepository.update(
      WorkTimeSettings(
        startHour: input.startHour,
        endHour: input.endHour,
        breakMinutesPerHour: input.breakMinutesPerHour,
        offWeekdays: {if (input.isFridayOff) DateTime.friday},
      ),
    );
  }

  Future<void> setPin(String pin) => securityActions.setPin(securityService, pin);
  Future<bool> disablePin(String pin) => securityActions.disablePin(securityService, pin);

  String createEncryptedBackup(String passphrase) {
    return backupActions.createBackup(
      taskRepository: taskRepository,
      financeRepository: financeRepository,
      goalRepository: goalRepository,
      plannedExpenseRepository: plannedExpenseRepository,
      debtRepository: debtRepository,
      allocationRepository: allocationRepository,
      categoryBudgetRepository: categoryBudgetRepository,
      passphrase: passphrase,
    );
  }

  Future<void> restoreEncryptedBackup({required String encryptedBackup, required String passphrase}) {
    return backupActions.restoreBackup(
      encryptedBackup: encryptedBackup,
      passphrase: passphrase,
      taskRepository: taskRepository,
      financeRepository: financeRepository,
      goalRepository: goalRepository,
      plannedExpenseRepository: plannedExpenseRepository,
      debtRepository: debtRepository,
      allocationRepository: allocationRepository,
      categoryBudgetRepository: categoryBudgetRepository,
    );
  }
}
