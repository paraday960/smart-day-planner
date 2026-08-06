import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommonDialogs {
  const CommonDialogs._();

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'تأیید',
    String cancelText = 'لغو',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  static Future<String?> askSecretText({
    required BuildContext context,
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('تأیید')),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  static Future<void> showLargeText({
    required BuildContext context,
    required String title,
    required String text,
    required String copyLabel,
    VoidCallback? onCopied,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                onCopied?.call();
              },
              icon: const Icon(Icons.copy),
              label: Text(copyLabel),
            ),
          ],
        ),
      ),
    );
  }
}
