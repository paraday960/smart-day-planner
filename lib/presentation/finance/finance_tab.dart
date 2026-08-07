import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../models/debt_item.dart';
import '../../models/finance_transaction.dart';
import '../../models/planned_expense_goal.dart';
import '../../services/chart_insight_service.dart';
import '../../utils/persian_format.dart';
import '../shared/empty_state_widget.dart';

class FinanceTab extends ConsumerWidget {
  const FinanceTab({
    super.key,
    required this.onAddTransaction,
    required this.onSetGoals,
    required this.onAddPlannedExpense,
    required this.onDeletePlannedExpense,
    required this.onAddDebt,
    required this.onPayDebt,
    required this.onDeleteDebt,
    required this.onAllocateToDebt,
    required this.onAllocateToPlannedExpense,
    required this.onSetCategoryBudget,
    required this.onDelete,
  });

  final ValueChanged<FinanceTransactionType> onAddTransaction;
  final VoidCallback onSetGoals;
  final VoidCallback onAddPlannedExpense;
  final ValueChanged<PlannedExpenseGoal> onDeletePlannedExpense;
  final VoidCallback onAddDebt;
  final ValueChanged<DebtItem> onPayDebt;
  final ValueChanged<DebtItem> onDeleteDebt;
  final ValueChanged<DebtItem> onAllocateToDebt;
  final ValueChanged<PlannedExpenseGoal> onAllocateToPlannedExpense;
  final VoidCallback onSetCategoryBudget;
  final ValueChanged<FinanceTransaction> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(financeRepositoryProvider);
    final goalRepository = ref.watch(goalRepositoryProvider);
    final plannedExpenseRepository = ref.watch(plannedExpenseRepositoryProvider);
    final debtRepository = ref.watch(debtRepositoryProvider);
    final allocationRepository = ref.watch(allocationRepositoryProvider);
    final categoryBudgetRepository = ref.watch(categoryBudgetRepositoryProvider);
    final goalPlanningService = ref.watch(goalPlanningServiceProvider);
    final debtPlanningService = ref.watch(debtPlanningServiceProvider);
    final envelopePlanningService = ref.watch(envelopePlanningServiceProvider);
    final chartInsightService = ref.watch(chartInsightServiceProvider);
    final assistant = ref.watch(financeAssistantProvider);

    final transactions = repository.transactions.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final summary = ref.watch(financeControllerProvider).buildSummary(repository);
    final incomeToday = summary.incomeToday;
    final expenseToday = summary.expenseToday;
    final incomeWeek = summary.incomeWeek;
    final expenseWeek = summary.expenseWeek;
    final incomeMonth = summary.incomeMonth;
    final expenseMonth = summary.expenseMonth;
    final netMonth = summary.netMonth;
    final hourly = summary.averageHourlyRate;
    final incomeByCategory = summary.incomeByCategory;
    final expenseByCategory = summary.expenseByCategory;
    final plannedExpenseStatuses = plannedExpenseRepository.activeItems
        .map((item) => goalPlanningService.statusFor(
              item,
              repository,
              allocatedAmount: envelopePlanningService.allocatedForPlannedExpense(item, allocationRepository),
            ))
        .toList();
    final debtStatuses = debtRepository.activeItems
        .map((item) => debtPlanningService.statusFor(
              item,
              repository,
              allocatedAmount: envelopePlanningService.allocatedForDebt(item, allocationRepository),
            ))
        .toList();
    final budgetWarnings = envelopePlanningService.budgetWarnings(
      budgets: categoryBudgetRepository.items,
      financeRepository: repository,
    );
    final cashflowPoints = chartInsightService.last7DaysCashflow(repository);
    final expenseShares = chartInsightService.monthlyExpenseCategoryShares(repository);
    final suggestions = assistant.suggestions(repository);

    final hasData = repository.transactions.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('حسابدار شخصی هوشمند', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('وقتی یک کار مرتبط با درآمد را کامل کنی، اپ مبلغ درآمد همان بازه را می‌پرسد و به درآمد فعلی اضافه می‌کند.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _MetricCard(title: 'درآمد امروز', value: PersianFormat.money(incomeToday, withCurrency: false), icon: Icons.trending_up)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(title: 'هزینه امروز', value: PersianFormat.money(expenseToday, withCurrency: false), icon: Icons.trending_down)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _MetricCard(title: 'درآمد ماه', value: PersianFormat.money(incomeMonth, withCurrency: false), icon: Icons.calendar_month)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(title: 'خالص ماه', value: PersianFormat.money(netMonth, withCurrency: false), icon: Icons.account_balance_wallet)),
          ],
        ),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('هدف‌های درآمدی'),
            subtitle: Text(
              'روزانه: ${goalRepository.dailyIncomeGoal == 0 ? 'تنظیم نشده' : PersianFormat.money(goalRepository.dailyIncomeGoal)} • ماه شمسی: ${goalRepository.monthlyIncomeGoal == 0 ? 'تنظیم نشده' : PersianFormat.money(goalRepository.monthlyIncomeGoal)}',
            ),
            trailing: FilledButton.tonal(
              onPressed: onSetGoals,
              child: const Text('تنظیم'),
            ),
          ),
        ),
        if (goalRepository.dailyIncomeGoal > 0)
          _GoalProgressCard(title: 'پیشرفت هدف امروز', current: incomeToday, goal: goalRepository.dailyIncomeGoal),
        if (goalRepository.monthlyIncomeGoal > 0)
          _GoalProgressCard(title: 'پیشرفت هدف ماه شمسی', current: incomeMonth, goal: goalRepository.monthlyIncomeGoal),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('بودجه دسته‌بندی‌ها'),
            subtitle: Text(categoryBudgetRepository.items.isEmpty
                ? 'برای تفریح، خوراک، رفت‌وآمد و... سقف ماهانه بگذار.'
                : '${PersianFormat.digits(categoryBudgetRepository.items.length)} بودجه فعال داری.'),
            trailing: FilledButton.tonal(
              onPressed: onSetCategoryBudget,
              child: const Text('تنظیم'),
            ),
          ),
        ),
        if (budgetWarnings.isNotEmpty)
          ...budgetWarnings.map((warning) => Card.outlined(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: Text(warning),
                ),
              )),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('هزینه‌های آینده'),
            subtitle: const Text('مثلاً: هفته بعد بیرون رفتن، یک میلیون تومان هزینه دارد.'),
            trailing: FilledButton.tonal(
              onPressed: onAddPlannedExpense,
              child: const Text('ثبت'),
            ),
          ),
        ),
        if (plannedExpenseStatuses.isNotEmpty)
          ...plannedExpenseStatuses.map(
            (status) => Card.outlined(
              child: ListTile(
                leading: CircleAvatar(child: Text('${PersianFormat.digits((status.progress * 100).round())}٪')),
                title: Text(status.goal.title),
                subtitle: Text(
                  '${PersianFormat.money(status.goal.targetAmount)} تا ${PersianFormat.jalaliLong(status.goal.dueAt)}\n'
                  'پاکت: ${PersianFormat.money(envelopePlanningService.allocatedForPlannedExpense(status.goal, allocationRepository))} • '
                  'باقی‌مانده: ${PersianFormat.money(envelopePlanningService.remainingForPlannedExpense(status.goal, allocationRepository))} • روزانه لازم: ${PersianFormat.money(status.requiredDailyIncome)}'
                  '${status.requiredWorkMinutesPerDay == 0 ? '' : ' • کار روزانه: ${PersianFormat.minutes(status.requiredWorkMinutesPerDay)}'}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'کنار گذاشتن پول',
                      onPressed: () => onAllocateToPlannedExpense(status.goal),
                      icon: const Icon(Icons.savings_outlined),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => onDeletePlannedExpense(status.goal),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('بدهی‌ها و طلب‌ها'),
            subtitle: const Text('مثلاً: به ممد یک میلیون بدهکارم و تا دو روز دیگر باید پس بدهم.'),
            trailing: FilledButton.tonal(
              onPressed: onAddDebt,
              child: const Text('ثبت'),
            ),
          ),
        ),
        if (debtStatuses.isNotEmpty)
          ...debtStatuses.map(
            (status) => Card.outlined(
              child: ListTile(
                leading: CircleAvatar(child: Text('${PersianFormat.digits((status.progress * 100).round())}٪')),
                title: Text('${status.item.type.faLabel} ${status.item.personName}'),
                subtitle: Text(
                  'مبلغ: ${PersianFormat.money(status.item.amount)} • مهلت: ${PersianFormat.jalaliLong(status.item.dueAt)}\n'
                  'پاکت: ${PersianFormat.money(envelopePlanningService.allocatedForDebt(status.item, allocationRepository))} • '
                  'باقی‌مانده: ${PersianFormat.money(envelopePlanningService.remainingForDebt(status.item, allocationRepository))} • روزانه لازم: ${PersianFormat.money(status.requiredDailyIncome)}'
                  '${status.requiredWorkMinutesPerDay == 0 ? '' : ' • کار روزانه: ${PersianFormat.minutes(status.requiredWorkMinutesPerDay)}'}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'کنار گذاشتن پول',
                      onPressed: () => onAllocateToDebt(status.item),
                      icon: const Icon(Icons.savings_outlined),
                    ),
                    IconButton(
                      tooltip: status.item.type == DebtType.debt ? 'ثبت پرداخت' : 'ثبت دریافت',
                      onPressed: () => onPayDebt(status.item),
                      icon: const Icon(Icons.payments_outlined),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => onDeleteDebt(status.item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.summarize_outlined),
            title: Text('گزارش سریع هفته: درآمد ${PersianFormat.money(incomeWeek)}، هزینه ${PersianFormat.money(expenseWeek)}'),
            subtitle: Text('گزارش ماه: درآمد ${PersianFormat.money(incomeMonth)}، هزینه ${PersianFormat.money(expenseMonth)}، خالص ${PersianFormat.money(netMonth)}'),
          ),
        ),
        const SizedBox(height: 12),
        _CashflowChartCard(points: cashflowPoints),
        const SizedBox(height: 12),
        _CategoryShareChartCard(points: expenseShares),
        const SizedBox(height: 12),
        _CategoryBreakdownCard(
          title: 'درآمد ماه بر اساس دسته‌بندی',
          values: incomeByCategory,
          total: incomeMonth,
          emptyText: 'این ماه درآمد دسته‌بندی‌شده‌ای ثبت نشده.',
        ),
        const SizedBox(height: 12),
        _CategoryBreakdownCard(
          title: 'هزینه ماه بر اساس دسته‌بندی',
          values: expenseByCategory,
          total: expenseMonth,
          emptyText: 'این ماه هزینه‌ای ثبت نشده.',
        ),
        if (hourly > 0) ...[
          const SizedBox(height: 12),
          Card.filled(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text('میانگین درآمد ساعتی: ${PersianFormat.hourRate(hourly)}'),
              subtitle: const Text('از روی درآمدهایی که هنگام تکمیل کار ثبت شده‌اند محاسبه می‌شود.'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onAddTransaction(FinanceTransactionType.income),
                icon: const Icon(Icons.add),
                label: const Text('درآمد دستی'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onAddTransaction(FinanceTransactionType.expense),
                icon: const Icon(Icons.remove),
                label: const Text('هزینه دستی'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('تحلیل مالی', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...suggestions.map((s) => Card.outlined(
              child: ListTile(
                leading: const Icon(Icons.insights),
                title: Text(s),
              ),
            )),
        const SizedBox(height: 16),
        Text('تراکنش‌های اخیر', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const Card.outlined(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('هنوز تراکنشی ثبت نشده.'),
            ),
          )
        else
          ...transactions.take(30).map(
                (transaction) => Card.outlined(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: transaction.type == FinanceTransactionType.income ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        transaction.type == FinanceTransactionType.income ? Icons.arrow_downward : Icons.arrow_upward,
                        color: transaction.type == FinanceTransactionType.income ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text('${transaction.type.faLabel}: ${PersianFormat.money(transaction.amount)}'),
                    subtitle: Text(
                      '${transaction.category} • ${PersianFormat.jalaliDateTime(transaction.createdAt)}${transaction.note.isEmpty ? '' : '\n${transaction.note}'}${transaction.hourlyRate == null ? '' : '\nدرآمد ساعتی این کار: ${PersianFormat.hourRate(transaction.hourlyRate!.round())}'}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'حذف تراکنش',
                      onPressed: () => onDelete(transaction),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

}

class _CashflowChartCard extends StatelessWidget {
  const _CashflowChartCard({required this.points});

  final List<DailyCashflowPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(0, (max, p) => [max, p.income, p.expense].reduce((a, b) => a > b ? a : b));
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('نمودار درآمد و هزینه ۷ روز اخیر', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (points.every((p) => p.income == 0 && p.expense == 0))
              const Text('هنوز داده‌ای برای نمودار هفتگی ثبت نشده.')
            else
              ...points.map((p) {
                final incomeValue = maxValue == 0 ? 0.0 : p.income / maxValue;
                final expenseValue = maxValue == 0 ? 0.0 : p.expense / maxValue;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(p.label),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: incomeValue, color: Colors.green),
                      const SizedBox(height: 3),
                      LinearProgressIndicator(value: expenseValue, color: Colors.red),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            const Text('سبز: درآمد • قرمز: هزینه'),
          ],
        ),
      ),
    );
  }
}

class _CategoryShareChartCard extends StatelessWidget {
  const _CategoryShareChartCard({required this.points});

  final List<CategorySharePoint> points;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('نمودار سهم هزینه‌های ماه شمسی', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (points.isEmpty)
              const Text('هنوز هزینه‌ای برای این ماه ثبت نشده.')
            else
              ...points.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(p.category)),
                            Text('${PersianFormat.money(p.amount)} • ${PersianFormat.digits((p.percent * 100).round())}٪'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: p.percent.clamp(0, 1).toDouble()),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.title,
    required this.values,
    required this.total,
    required this.emptyText,
  });

  final String title;
  final Map<String, int> values;
  final int total;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (values.isEmpty)
              Text(emptyText)
            else
              ...values.entries.take(5).map((entry) {
                final percent = total <= 0 ? 0.0 : entry.value / total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(PersianFormat.money(entry.value)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: percent.clamp(0, 1).toDouble()),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

}

class _GoalProgressCard extends StatelessWidget {
  const _GoalProgressCard({required this.title, required this.current, required this.goal});

  final String title;
  final int current;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (current / goal).clamp(0, 1).toDouble();
    final remaining = (goal - current).clamp(0, goal).toInt();

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                Text('${PersianFormat.digits((progress * 100).round())}٪'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text('ثبت‌شده: ${PersianFormat.money(current)} • باقی‌مانده: ${PersianFormat.money(remaining)}'),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget { 
  const _MetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(title),
          ],
        ),
      ),
    );
  }
}

