import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? scheme.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            Text(
              title,
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
