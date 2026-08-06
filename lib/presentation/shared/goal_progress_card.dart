import 'package:flutter/material.dart';

import '../../utils/persian_format.dart';

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key, required this.title, required this.current, required this.goal});

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
