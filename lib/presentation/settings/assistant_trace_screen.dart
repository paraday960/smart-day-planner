import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_day_planner/services/assistant_trace.dart';
import 'package:smart_day_planner/services/self_healing.dart';
import 'package:smart_day_planner/services/app_trace.dart';

class AssistantTraceScreen extends StatelessWidget {
  const AssistantTraceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final traces = TraceStore.instance.all.reversed.toList();
    final appEvents = AppTrace.instance.events;
    final healEvents =
        SelfHealing.instance.events.toList().reversed.take(5).toList();
    final disabled = SelfHealing.instance.disabledFeatures;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🔍 ردپا'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'دستیار', icon: Icon(Icons.chat)),
              Tab(text: 'برنامه', icon: Icon(Icons.apps)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'پاک کردن',
              onPressed: () {
                TraceStore.instance.clear();
                AppTrace.instance.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ردپاها پاک شدند')),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAssistantTab(context, traces),
            _buildAppTab(context, appEvents, healEvents, disabled),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantTab(BuildContext context, List<AssistantTrace> traces) {
    if (traces.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'هنوز هیچ درخواستی ثبت نشده است.\n'
            'یک بار با دستیار صحبت کنید، سپس به این صفحه بیایید.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
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
                color: errors == 0 ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            title: Text(t.userText, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                            fontFamily: 'monospace', fontSize: 11, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('کپی گزارش'),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: t.toReport()));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('گزارش کپی شد')),
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
    );
  }

  Widget _buildAppTab(
    BuildContext context,
    List<AppTraceEvent> appEvents,
    List<HealingEvent> healEvents,
    Map<String, String> disabled,
  ) {
    if (appEvents.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24),
        child: Text('هنوز رویدادی ثبت نشده است.\nبا برنامه کار کنید تا اینجا پر شود.', textAlign: TextAlign.center)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (disabled.isNotEmpty || healEvents.isNotEmpty)
        Card(color: Colors.orange.shade50, margin: const EdgeInsets.all(8), child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.healing, size: 18, color: Colors.orange), SizedBox(width: 8),
              Text('سیستم خودترمیمی', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 6),
            if (disabled.isNotEmpty)
              ...disabled.keys.map((k) => Padding(padding: const EdgeInsets.only(top: 2), child: Text('⏸️  $k غیرفعال موقت'))),
            if (healEvents.isNotEmpty)
              ...healEvents.map((e) => Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.toString()))),
          ]),
        )),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: appEvents.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = appEvents[i];
          final hasDetails = e.inputs.isNotEmpty || e.outputs.isNotEmpty || e.source != null || e.errorMessage != null;
          return ExpansionTile(
            dense: true,
            leading: Text(e.emoji, style: const TextStyle(fontSize: 18)),
            title: Text(e.action, style: const TextStyle(fontSize: 13)),
            subtitle: Text('${e.categoryLabel} • ${e.time.toLocal().toString().substring(11, 19)}', style: const TextStyle(fontSize: 10)),
            trailing: e.duration != null
                ? Text('${e.duration!.inMilliseconds}ms', style: const TextStyle(fontSize: 10, color: Colors.grey))
                : null,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: hasDetails ? [
              if (e.source != null)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('📍 ${e.source}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey))),
              if (e.inputs.isNotEmpty) ...[
                const Text('📥 ورودی‌ها:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ...e.inputs.entries.map((x) => Padding(padding: const EdgeInsets.only(right: 8), child: Text('  • ${x.key} = ${x.value}', style: const TextStyle(fontSize: 10)))),
              ],
              if (e.outputs.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('📤 خروجی‌ها:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ...e.outputs.entries.map((x) => Padding(padding: const EdgeInsets.only(right: 8), child: Text('  • ${x.key} = ${x.value}', style: const TextStyle(fontSize: 10)))),
              ],
              if (e.errorMessage != null) ...[
                const SizedBox(height: 4),
                Text('❌ خطا: ${e.errorMessage}', style: const TextStyle(fontSize: 10, color: Colors.red)),
              ],
            ] : const [Padding(padding: EdgeInsets.all(8), child: Text('جزئیات بیشتری ثبت نشده', style: TextStyle(fontSize: 10, color: Colors.grey)))],
          );
        },
      )),
    ]);
  }
}
