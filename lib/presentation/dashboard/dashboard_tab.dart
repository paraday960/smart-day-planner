import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../models/task.dart';
import '../../utils/persian_format.dart';
import '../shared/empty_state_widget.dart';
import '../shared/goal_progress_card.dart';
import '../shared/metric_card.dart';
import '../shared/plan_card.dart';

class DashboardTab extends ConsumerWidget {
  const DashboardTab({
    super.key,
    required this.onEdit,
    required this.onComplete,
  });

  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRepository = ref.watch(taskRepositoryProvider);
    final financeRepository = ref.watch(financeRepositoryProvider);
    final goalRepository = ref.watch(goalRepositoryProvider);
    final plannedExpenseRepository = ref.watch(plannedExpenseRepositoryProvider);
    final debtRepository = ref.watch(debtRepositoryProvider);
    final availabilityRepository = ref.watch(availabilityRepositoryProvider);
    final dashboardController = ref.watch(dashboardControllerProvider);
    final timeAwarePlanner = ref.watch(timeAwarePlannerProvider);
    final tasks = taskRepository.tasks;

    final state = dashboardController.build(
      tasks: tasks,
      financeRepository: financeRepository,
      goalRepository: goalRepository,
      plannedExpenseRepository: plannedExpenseRepository,
      debtRepository: debtRepository,
    );
    final workWindowPlan = timeAwarePlanner.buildWorkWindowPlan(
      tasks: tasks,
      settings: availabilityRepository.settings,
    );
    final dailyGoal = goalRepository.dailyIncomeGoal;
    final monthlyGoal = goalRepository.monthlyIncomeGoal;
    final todayIncome = financeRepository.incomeToday();
    final monthIncome = financeRepository.incomeThisMonth();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (state.brainProfile != null) Card.filled(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, size: 20),
                    const SizedBox(width: 8),
                    Text('مغز هوشمند یکپارچه 🧠', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text('\${PersianFormat.digits(state.brainProfile!.brainScore)}/۱۰۰', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(state.brainProfile!.nextAction, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                ...state.brainProfile!.personalizedInsights.take(2).map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(e, style: Theme.of(context).textTheme.bodySmall))]))),
              ],
            ),
          ),
        ),
        if (state.brainProfile != null) const SizedBox(height: 12),
        if (tasks.isEmpty && financeRepository.transactions.isEmpty)
          EmptyStateWidget(icon: Icons.waving_hand, title: 'خوش اومدی! 👋', subtitle: 'هنوز با هم آشنا نشدیم — ۳ تا کار و ۲ تا هزینه ثبت کن تا مغز هوشمندت رو بشناسمت', hint: 'دستیار همه رو خودکار انجام می‌ده، فقط بگو: «همه اطلاعات رو نشون بده»', actionLabel: 'شروع با دستیار', onAction: () => DefaultTabController.of(context).animateTo(3)),
        Card.filled(
          child: ListTile(
            leading: const Icon(Icons.today),
            title: const Text('امروز به تقویم ایران'),
            subtitle: Text(PersianFormat.todayJalali()),
          ),
        ),
        const SizedBox(height: 12),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('محدودیت زمانی امروز'),
            subtitle: Text(
              '${availabilityRepository.todaySummary()}${workWindowPlan.isEmpty ? '' : '\n${PersianFormat.digits(workWindowPlan.length)} کار در پنجره کاری امروز جا می‌شود.'}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: MetricCard(title: 'کارهای باز', value: PersianFormat.digits(state.openCount), icon: Icons.pending_actions)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(title: 'انجام‌شده امروز', value: PersianFormat.digits(state.doneTodayCount), icon: Icons.done_all)),
          ],
        ),
        if (dailyGoal > 0 || monthlyGoal > 0) ...[
          const SizedBox(height: 12),
          if (dailyGoal > 0) GoalProgressCard(title: 'هدف درآمد امروز', current: todayIncome, goal: dailyGoal),
          if (monthlyGoal > 0) GoalProgressCard(title: 'هدف درآمد ماه شمسی', current: monthIncome, goal: monthlyGoal),
        ],
        _InsightSection(
          title: 'تصمیم هوشمند زمان و درآمد',
          icon: Icons.psychology_alt_outlined,
          items: state.decisionInsights,
        ),
        if (state.plannedExpenseMessages.isNotEmpty)
          _InsightSection(
            title: 'برنامه‌ریزی هزینه‌های آینده',
            icon: Icons.savings_outlined,
            items: state.plannedExpenseMessages,
          ),
        if (state.debtMessages.isNotEmpty)
          _InsightSection(
            title: 'بدهی‌ها و طلب‌ها',
            icon: Icons.account_balance_outlined,
            items: state.debtMessages,
          ),
        _InsightSection(
          title: 'تحلیل عملکرد هفته',
          icon: Icons.query_stats_outlined,
          items: state.weeklyInsights,
        ),
        _InsightSection(
          title: 'تحلیل عادت‌های تو',
          icon: Icons.auto_graph_outlined,
          items: state.habitInsights,
        ),
        _InsightSection(
          title: 'پیشنهادهای هوشمند',
          icon: Icons.lightbulb_outline,
          items: state.suggestions,
        ),
        const SizedBox(height: 16),
        Text('برنامه پیشنهادی امروز', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (state.todayPlan.isEmpty)
          const Card.outlined(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('برای امروز برنامه‌ای ساخته نشد. کار جدید اضافه کن یا مهلت انجام/زمان تخمینی را تنظیم کن.'),
            ),
          )
        else
          ...state.todayPlan.map((item) => PlanCard(item: item, onEdit: onEdit, onComplete: onComplete)),
      ],
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Card.outlined(
            child: ListTile(
              leading: Icon(icon),
              title: Text(item),
            ),
          ),
        ),
      ],
    );
  }
}
