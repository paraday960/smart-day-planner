import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/persian_format.dart';
import 'common_dialogs.dart';

class TaskDialogs {
  const TaskDialogs._();

  static Future<int?> askActualMinutes(BuildContext context, int initialMinutes) async {
    final controller = TextEditingController(text: PersianFormat.digits(initialMinutes));
    final result = await showDialog<int>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('زمان واقعی انجام کار'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'چند دقیقه طول کشید؟',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(PersianFormat.englishDigits(controller.text));
                if (value == null || value < 1) return;
                Navigator.pop(context, value);
              },
              child: const Text('ثبت'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  static Future<bool> confirmDelete(BuildContext context, Task task) {
    return CommonDialogs.confirm(
      context: context,
      title: 'حذف کار',
      message: '«${task.title}» حذف شود؟',
      confirmText: 'حذف',
    );
  }
}
