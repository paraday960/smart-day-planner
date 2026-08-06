import 'package:flutter/material.dart';

class SecurityDialogs {
  const SecurityDialogs._();

  static Future<String?> setPin(BuildContext context) async {
    final pinController = TextEditingController();
    final repeatController = TextEditingController();
    String error = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تنظیم رمز برنامه'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'رمز حداقل ۴ رقم', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: repeatController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'تکرار رمز',
                    border: const OutlineInputBorder(),
                    errorText: error.isEmpty ? null : error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
              FilledButton(
                onPressed: () {
                  if (pinController.text.trim().length < 4) {
                    setDialogState(() => error = 'رمز باید حداقل ۴ رقم باشد.');
                    return;
                  }
                  if (pinController.text != repeatController.text) {
                    setDialogState(() => error = 'تکرار رمز یکسان نیست.');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );

    final pin = saved == true ? pinController.text : null;
    pinController.dispose();
    repeatController.dispose();
    return pin;
  }
}
