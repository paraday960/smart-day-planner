import 'package:shared_preferences/shared_preferences.dart';

import '../domain/services/notification_service_port.dart';
import 'notification_service.dart';
import 'smart_notification_advisor.dart';
import 'allocation_repository.dart';
import 'category_budget_repository.dart';
import 'debt_repository.dart';
import 'finance_repository.dart';
import 'planned_expense_repository.dart';

class SmartNotificationScheduler {
  SmartNotificationScheduler({
    NotificationServicePort? notificationService,
    SmartNotificationAdvisor advisor = const SmartNotificationAdvisor(),
  })  : _notificationService = notificationService ?? NotificationService.instance,
        _advisor = advisor;

  final NotificationServicePort _notificationService;
  final SmartNotificationAdvisor _advisor;

  /// شمارندهٔ ماندگار شناسهٔ هشدارهای هوشمند — قبلاً از صفر شروع
  /// می‌شد و بعد از هر ری‌استارت، اعلان‌های جدید جای اعلان‌های قبلی
  /// (با همان id) را می‌گرفتند.
  static const _counterKey = 'smart_day_planner.notification.smart_counter.v1';

  Future<int> scheduleTomorrowMorningAlerts({
    required DebtRepository debts,
    required PlannedExpenseRepository plannedExpenses,
    required AllocationRepository allocations,
    required CategoryBudgetRepository budgets,
    required FinanceRepository finance,
  }) async {
    final alerts = _advisor.buildAlerts(
      debts: debts,
      plannedExpenses: plannedExpenses,
      allocations: allocations,
      budgets: budgets,
      finance: finance,
    ).where((a) => !a.contains('فعلاً هشدار فوری نداری')).toList();

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final when = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);

    final prefs = await SharedPreferences.getInstance();
    var count = prefs.getInt(_counterKey) ?? 0;
    var scheduled = 0;
    for (final alert in alerts.take(5)) {
      await _notificationService.scheduleSmartAlert(
        id: 900000 + count,
        title: 'هشدار هوشمند مالی',
        body: alert,
        when: when.add(Duration(minutes: scheduled * 3)),
      );
      count++;
      scheduled++;
    }
    await prefs.setInt(_counterKey, count);
    return scheduled;
  }
}
