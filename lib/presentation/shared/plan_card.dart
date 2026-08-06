import 'package:flutter/material.dart';

import '../../models/scheduled_item.dart';
import '../../models/task.dart';
import '../../utils/persian_format.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.item, required this.onEdit, required this.onComplete});

  final ScheduledItem item;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onComplete;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: ListTile(
        leading: CircleAvatar(child: Text(PersianFormat.digits(item.priorityScore))),
        title: Text(item.task.title),
        subtitle: Text('${PersianFormat.time(item.start)} تا ${PersianFormat.time(item.end)} • ${item.reason}'),
        trailing: Wrap(
          children: [
            IconButton(onPressed: () => onEdit(item.task), icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: () => onComplete(item.task), icon: const Icon(Icons.check_circle_outline)),
          ],
        ),
      ),
    );
  }
}
