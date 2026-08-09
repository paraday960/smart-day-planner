import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_day_planner/services/assistant_trace.dart';
import 'package:smart_day_planner/services/self_healing.dart';

/// صفحه‌ای که ردپای کامل پردازش درخواست‌های دستیار را نشان می‌دهد.
/// کاربر می‌تواند گزارش را کپی کرده و برای عیب‌یابی ارسال کند.
class AssistantTraceScreen extends StatelessWidget {
  const AssistantTraceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final traces = TraceStore.instance.all.reversed.toList();
    final healEvents = SelfHealing.instance.events.toList().reversed.take(5).toList();
    final disabled = SelfHealing.instance.disabledFeatures;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 ردپای دستیار'),
        actions: [
          if (traces.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'پاک کردن',
              onPressed: () {
                TraceStore.instance.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ردپاها پاک شدند')),
                );
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: traces.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'هنوز هیچ درخواستی ثبت نشده است.\n'
                  'یک بار با دستیار صحبت کنید، سپس به این صفحه بیایید.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (disabled.isNotEmpty || healEvents.isNotEmpty)
                  Card(
                    color: Colors.orange.shade50,
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.healing, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('سیستم خودترمیمی',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 6),
                          if (disabled.isNotEmpty)
                            ...disabled.keys.map((k) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('⏸️  $k غیرفعال موقت'),
                                )),
                          if (healEvents.isNotEmpty)
                            ...healEvents.map((e) => Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(e.toString()),
                                )),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: traces.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final t = traces[i];
                      final errors = t.steps.where((s) => !s.success).length;
                      return Card(
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: errors == 0
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            child: Icon(
                              errors == 0 ? Icons.check : Icons.warning,
                              color:
                                  errors == 0 ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            t.userText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${t.steps.length} مرحله • ${t.startedAt.toLocal().toString().substring(0, 19)}'
                            '${errors > 0 ? " • $errors خطا" : ""}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      t.toReport(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('کپی گزارش'),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: t.toReport()),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'گزارش کپی شد. آن را برای پشتیبانی بفرستید.'),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
