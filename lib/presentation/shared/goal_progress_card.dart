import 'package:flutter/material.dart';

import '../../utils/persian_format.dart';

class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key, required this.title, required this.current, required this.goal});

  final String title;
  final int current;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = goal <= 0 ? 0.0 : (current / goal).clamp(0, 1).toDouble();
    final remaining = (goal - current).clamp(0, goal).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${PersianFormat.digits((progress * 100).round())}٪',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              'ثبتشده: ${PersianFormat.money(current)} • باقیمانده: ${PersianFormat.money(remaining)}',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
