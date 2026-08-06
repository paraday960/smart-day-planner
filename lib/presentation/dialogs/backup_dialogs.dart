import 'package:flutter/material.dart';

import 'common_dialogs.dart';

class RestoreBackupInput {
  const RestoreBackupInput({required this.encryptedBackup, required this.passphrase});

  final String encryptedBackup;
  final String passphrase;
}

class BackupDialogs {
  const BackupDialogs._();

  static Future<String?> askBackupPassphrase(BuildContext context, {required String title}) {
    return CommonDialogs.askSecretText(
      context: context,
      title: title,
      label: 'رمز بکاپ حداقل ۶ کاراکتر',
    );
  }

  static Future<RestoreBackupInput?> restore(BuildContext context) async {
    final backupController = TextEditingController();
    final passController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بازیابی بکاپ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: backupController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'متن بکاپ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'رمز بکاپ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                const Text('هشدار: با بازیابی، داده‌های فعلی با اطلاعات بکاپ جایگزین می‌شود.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
            FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('بازیابی')),
          ],
        ),
      ),
    );

    final input = confirmed == true
        ? RestoreBackupInput(
            encryptedBackup: backupController.text,
            passphrase: passController.text,
          )
        : null;
    backupController.dispose();
    passController.dispose();
    return input;
  }
}
