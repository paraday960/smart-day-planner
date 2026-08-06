import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../models/task.dart';
import '../../utils/persian_format.dart';
import '../shared/empty_state_widget.dart';

class TasksTab extends ConsumerWidget {
  const TasksTab({
    super.key,
    required this.onEdit,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
    required this.onTogglePin,
  });
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onComplete;
  final ValueChanged<Task> onReopen;
  final ValueChanged<Task> onDelete;
  final ValueChanged<Task> onTogglePin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskRepositoryProvider).tasks;
    final planner = ref.watch(smartPlannerProvider);
    final open = tasks.where((task) => !task.isDone).toList()
      ..sort((a, b) => planner.priorityScore(b).compareTo(planner.priorityScore(a)));
    final done = tasks.where((task) => task.isDone).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('کارهای باز', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (open.isEmpty)
          EmptyStateWidget(icon: Icons.checklist_outlined, title: 'هنوز کاری نساختی', subtitle: 'اولین کارت رو بساز تا دستیار هوشمند برنامه‌ات رو بچینه', hint: 'بگو: «کار جدید: تماس با مشتری فردا ساعت ۱۰» یا دکمه + پایین رو بزن', actionLabel: 'فهمیدم', onAction: () {})
        else
          ...open.map(
            (task) => TaskCard(
              task: task,
              score: planner.priorityScore(task),
              reason: planner.explainPriority(task),
              onEdit: onEdit,
              onComplete: onComplete,
              onReopen: onReopen,
              onDelete: onDelete,
              onTogglePin: onTogglePin,
            ),
          ),
        const SizedBox(height: 20),
        Text('انجام‌شده‌ها', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (done.isEmpty)
          const Card.outlined(child: Padding(padding: EdgeInsets.all(16), child: Text('هنوز کاری کامل نشده — یه کار باز رو تکمیل کن!')))
        else
          ...done.map(
            (task) => TaskCard(
              task: task,
              score: planner.priorityScore(task),
              reason: 'کامل‌شده در ${PersianFormat.minutes(task.actualMinutes ?? task.estimatedMinutes)}',
              onEdit: onEdit,
              onComplete: onComplete,
              onReopen: onReopen,
              onDelete: onDelete,
              onTogglePin: onTogglePin,
            ),
          ),
      ],
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.score,
    required this.reason,
    required this.onEdit,
    required this.onComplete,
    required this.onReopen,
    required this.onDelete,
    required this.onTogglePin,
  });

  final Task task;
  final int score;
  final String reason;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onComplete;
  final ValueChanged<Task> onReopen;
  final ValueChanged<Task> onDelete;
  final ValueChanged<Task> onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: task.isDone ? Colors.green.shade100 : null,
          child: task.isDone ? const Icon(Icons.check, color: Colors.green) : Text(PersianFormat.digits(score)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: task.isDone ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
              ),
            ),
            if (task.isPinned) const Icon(Icons.push_pin, size: 18),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${task.category} • ${PersianFormat.minutes(task.estimatedMinutes)} • اهمیت ${PersianFormat.digits(task.importance)}/۵ • انرژی ${task.energy.faLabel}\n$reason${task.dueAt == null ? '' : '\nمهلت انجام: ${PersianFormat.jalaliLong(task.dueAt!)} (${PersianFormat.relativeDue(task.dueAt!)})'}',
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'done':
                onComplete(task);
                break;
              case 'reopen':
                onReopen(task);
                break;
              case 'edit':
                onEdit(task);
                break;
              case 'pin':
                onTogglePin(task);
                break;
              case 'delete':
                onDelete(task);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!task.isDone) const PopupMenuItem(value: 'done', child: Text('کامل شد')),
            if (task.isDone) const PopupMenuItem(value: 'reopen', child: Text('بازگردانی')),
            const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
            PopupMenuItem(value: 'pin', child: Text(task.isPinned ? 'برداشتن سنجاق' : 'سنجاق')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }
}
