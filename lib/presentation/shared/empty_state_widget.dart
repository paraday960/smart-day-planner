import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (hint != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Text(hint!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
