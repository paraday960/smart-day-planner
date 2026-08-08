import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/local_assistant_memory.dart';
import '../../services/skill_service.dart';

class LearningDashboardScreen extends StatefulWidget {
  const LearningDashboardScreen({super.key});

  @override
  State<LearningDashboardScreen> createState() => _LearningDashboardScreenState();
}

class _LearningDashboardScreenState extends State<LearningDashboardScreen> {
  final _memory = LocalAssistantMemory.instance;
  final _skill = SkillService.instance;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _memory.load();
    _skill.load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _memory.allEntries.entries
        .where((e) => _filter.isEmpty || e.key.contains(_filter.toLowerCase()) || e.value.contains(_filter))
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد یادگیری'),
        actions: [
          IconButton(
            tooltip: 'صادرات',
            icon: const Icon(Icons.upload),
            onPressed: _export,
          ),
          IconButton(
            tooltip: 'واردات',
            icon: const Icon(Icons.download),
            onPressed: _import,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Text('پاک کردن همه')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // کارت مهارت
          _SkillSummaryCard(skill: _skill),
          const SizedBox(height: 16),
          // اچیومنت‌ها
          _AchievementsCard(skill: _skill),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'جستجو در یادگیری‌ها...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 12),
          Text('حافظه یادگیری محلی (${entries.length} مورد)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('هنوز چیزی یاد نگرفته — یه سوال جدید که محلی بلد نیست بپرس تا آنلاین جواب بده و یاد بگیره!')))
          else
            ...entries.map((e) => Card(
                  child: ListTile(
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(e.value, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _editEntry(e.key, e.value);
                        if (v == 'delete') _deleteEntry(e.key);
                        if (v == 'copy') _copy(e.value);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                        const PopupMenuItem(value: 'copy', child: Text('کپی جواب')),
                        const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          // تاریخچه مهارت
          Text('تاریخچه امتیاز', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._skill.history.reversed.take(10).map((h) => Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.amber.shade100, child: Text('+${h['points']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  title: Text(h['reason']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text((h['at'] ?? '').toString().substring(0, 16), style: const TextStyle(fontSize: 11)),
                  trailing: Text('Lv.${h['level']}', style: const TextStyle(fontSize: 11)),
                ),
              )),
        ],
      ),
    );
  }

  void _editEntry(String oldKey, String oldValue) async {
    final qCtrl = TextEditingController(text: oldKey);
    final aCtrl = TextEditingController(text: oldValue);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ویرایش یادگیری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'سؤال'), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'جواب'), maxLines: 4),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ذخیره')),
        ],
      ),
    );
    if (ok == true) {
      await _memory.updateEntry(oldKey, qCtrl.text, aCtrl.text);
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ویرایش شد')));
    }
  }

  void _deleteEntry(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف؟'),
        content: Text('«$key» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await _memory.deleteEntry(key);
      setState(() {});
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کپی شد')));
  }

  void _export() {
    final json = _memory.exportJson();
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON کپی شد — می‌تونی ذخیره کنی')));
  }

  void _import() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('واردات JSON'),
        content: TextField(controller: ctrl, maxLines: 6, decoration: const InputDecoration(hintText: 'JSON را اینجا پیست کن')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('وارد کن')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _memory.importJson(ctrl.text.trim());
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وارد شد')));
    }
  }

  void _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('پاک کردن همه؟'),
        content: const Text('همه ۲۰۰ مورد حافظه پاک شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('پاک کن')),
        ],
      ),
    );
    if (ok == true) {
      await _memory.clear();
      setState(() {});
    }
  }
}

class _SkillSummaryCard extends StatelessWidget {
  const _SkillSummaryCard({required this.skill});
  final SkillService skill;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text('سطح ${skill.level} — ${skill.levelLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${skill.score} امتیاز', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: skill.progressFraction, minHeight: 8, backgroundColor: Colors.grey.shade300),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${skill.progressToNextLevel}/100 تا سطح بعد', style: const TextStyle(fontSize: 11)),
                Text('استریک: ${skill.streak} روز 🔥', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: skill.achievements.map((a) => Chip(label: Text(a, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)).toList(),
            ),
            if (skill.achievements.isEmpty) const Text('هنوز اچیومنتی نداری — اولین یادگیری رو بگیر!', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.skill});
  final SkillService skill;

  @override
  Widget build(BuildContext context) {
    final all = [
      {'id': 'اولین_یادگیری', 'title': 'اولین قدم 🌟', 'desc': 'اولین یادگیری'},
      {'id': 'پنج_یادگیری', 'title': '۵ تایی 🔥', 'desc': '۵ چیز یاد گرفتی'},
      {'id': 'سطح_۲', 'title': 'سطح ۲', 'desc': '۱۰۰ امتیاز'},
      {'id': 'استریک_۳', 'title': '۳ روزه', 'desc': '۳ روز متوالی'},
      {'id': 'استریک_۷', 'title': 'هفتگی', 'desc': '۷ روز متوالی'},
      {'id': 'استاد', 'title': 'استاد ⭐', 'desc': '۱۰۰۰ امتیاز'},
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اچیومنت‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: all.map((a) {
                final unlocked = skill.hasAchievement(a['id']!);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: unlocked ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: unlocked ? Colors.green : Colors.grey.shade400),
                  ),
                  child: Text('${a['title']} ${unlocked ? '✅' : '🔒'}', style: TextStyle(fontSize: 11, color: unlocked ? Colors.green.shade800 : Colors.grey)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
