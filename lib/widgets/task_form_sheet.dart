import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/task.dart';
import '../utils/persian_format.dart';

class TaskFormSheet extends StatefulWidget {
  const TaskFormSheet({super.key, this.initialTask});

  final Task? initialTask;

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _categoryController;
  late final TextEditingController _minutesController;

  late int _importance;
  late EnergyLevel _energy;
  DateTime? _dueAt;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _categoryController = TextEditingController(text: task?.category ?? 'عمومی');
    _minutesController = TextEditingController(text: PersianFormat.digits(task?.estimatedMinutes ?? 30));
    _importance = task?.importance ?? 3;
    _energy = task?.energy ?? EnergyLevel.medium;
    _dueAt = task?.dueAt;
    _isPinned = task?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.initialTask == null ? 'افزودن کار جدید' : 'ویرایش کار',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'عنوان کار',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'عنوان را وارد کن' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات اختیاری',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'دسته‌بندی',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'زمان تخمینی / دقیقه',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(PersianFormat.englishDigits(value ?? ''));
                          if (parsed == null || parsed < 5) return 'حداقل ۵ دقیقه';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('اهمیت: ${PersianFormat.digits(_importance)} از ۵'),
                Slider(
                  value: _importance.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: PersianFormat.digits(_importance),
                  onChanged: (value) => setState(() => _importance = value.round()),
                ),
                const SizedBox(height: 8),
                SegmentedButton<EnergyLevel>(
                  segments: EnergyLevel.values
                      .map((e) => ButtonSegment(value: e, label: Text('انرژی ${e.faLabel}')))
                      .toList(),
                  selected: {_energy},
                  onSelectionChanged: (value) => setState(() => _energy = value.first),
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(_dueAt == null ? 'بدون مهلت انجام' : _formatDateTime(_dueAt!)),
                    subtitle: const Text('مهلت انجام اختیاری'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (_dueAt != null)
                          IconButton(
                            tooltip: 'حذف مهلت انجام',
                            onPressed: () => setState(() => _dueAt = null),
                            icon: const Icon(Icons.close),
                          ),
                        FilledButton.tonal(
                          onPressed: _pickDueAt,
                          child: const Text('انتخاب'),
                        ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile(
                  value: _isPinned,
                  onChanged: (value) => setState(() => _isPinned = value),
                  title: const Text('سنجاق کردن به اولویت بالا'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('ذخیره'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(hours: 2));
    final j = Jalali.fromDateTime(initial);

    final yearController = TextEditingController(text: PersianFormat.digits(j.year));
    final monthController = TextEditingController(text: PersianFormat.digits(j.month));
    final dayController = TextEditingController(text: PersianFormat.digits(j.day));
    final hourController = TextEditingController(text: PersianFormat.digits(initial.hour));
    final minuteController = TextEditingController(text: PersianFormat.digits(initial.minute));

    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('انتخاب مهلت انجام شمسی'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('امروز ساعت ۲۲'),
                      onPressed: () {
                        final today = DateTime.now();
                        Navigator.pop(context, DateTime(today.year, today.month, today.day, 22));
                      },
                    ),
                    ActionChip(
                      label: const Text('فردا ساعت ۹'),
                      onPressed: () {
                        final tomorrow = DateTime.now().add(const Duration(days: 1));
                        Navigator.pop(context, DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9));
                      },
                    ),
                    ActionChip(
                      label: const Text('هفته آینده'),
                      onPressed: () => Navigator.pop(context, DateTime.now().add(const Duration(days: 7))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _numberField(yearController, 'سال')),
                    const SizedBox(width: 8),
                    Expanded(child: _numberField(monthController, 'ماه')),
                    const SizedBox(width: 8),
                    Expanded(child: _numberField(dayController, 'روز')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _numberField(hourController, 'ساعت')),
                    const SizedBox(width: 8),
                    Expanded(child: _numberField(minuteController, 'دقیقه')),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('تاریخ را بر اساس تقویم شمسی ایران وارد کن.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                try {
                  final jy = int.parse(PersianFormat.englishDigits(yearController.text));
                  final jm = int.parse(PersianFormat.englishDigits(monthController.text));
                  final jd = int.parse(PersianFormat.englishDigits(dayController.text));
                  final h = int.parse(PersianFormat.englishDigits(hourController.text)).clamp(0, 23).toInt();
                  final m = int.parse(PersianFormat.englishDigits(minuteController.text)).clamp(0, 59).toInt();
                  final gregorian = Jalali(jy, jm, jd).toGregorian();
                  Navigator.pop(context, DateTime(gregorian.year, gregorian.month, gregorian.day, h, m));
                } catch (_) {
                  // ورودی نامعتبر را نادیده می‌گیریم تا کاربر اصلاح کند.
                }
              },
              child: const Text('تأیید'),
            ),
          ],
        ),
      ),
    );

    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    hourController.dispose();
    minuteController.dispose();

    if (selected == null) return;
    setState(() => _dueAt = selected);
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final initial = widget.initialTask;
    final task = Task(
      id: initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      notes: _notesController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? 'عمومی' : _categoryController.text.trim(),
      createdAt: initial?.createdAt ?? DateTime.now(),
      dueAt: _dueAt,
      importance: _importance,
      energy: _energy,
      estimatedMinutes: int.parse(PersianFormat.englishDigits(_minutesController.text)),
      actualMinutes: initial?.actualMinutes,
      status: initial?.status ?? TaskStatus.todo,
      completedAt: initial?.completedAt,
      isPinned: _isPinned,
    );

    Navigator.of(context).pop(task);
  }

  String _formatDateTime(DateTime value) => PersianFormat.jalaliLong(value);
}
