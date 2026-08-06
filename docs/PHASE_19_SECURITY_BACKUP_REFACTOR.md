# فاز ۱۹ اضافه شد — استخراج Security/Backup Dialogs و Action Controllerها

فاز ۱۹ ادامه مسیر refactor است و روی جدا کردن بخش‌های امنیت، بکاپ و عملیات باقی‌مانده از `home_screen.dart` تمرکز دارد.

## ۱. SecurityActionsController

فایل جدید:

```text
lib/application/actions/security_actions_controller.dart
```

این controller عملیات امنیتی را انجام می‌دهد:

- تنظیم PIN
- حذف PIN بعد از اعتبارسنجی رمز فعلی

## ۲. BackupActionsController

فایل جدید:

```text
lib/application/actions/backup_actions_controller.dart
```

این controller عملیات بکاپ را مدیریت می‌کند:

- ساخت بکاپ رمزنگاری‌شده
- بازیابی بکاپ
- اعمال داده‌های بازیابی‌شده روی repositoryها

## ۳. SecurityDialogs

فایل جدید:

```text
lib/presentation/dialogs/security_dialogs.dart
```

شامل dialog تنظیم/تغییر رمز برنامه.

## ۴. BackupDialogs

فایل جدید:

```text
lib/presentation/dialogs/backup_dialogs.dart
```

شامل:

- پرسیدن رمز بکاپ
- دریافت متن بکاپ و رمز برای بازیابی

## ۵. تغییرات HomeScreen

در `home_screen.dart` این موارد سبک‌تر شدند:

- `_openSetPinDialog`
- `_disablePin`
- `_createEncryptedBackup`
- `_shareEncryptedBackupFile`
- `_restoreEncryptedBackup`

حالا HomeScreen بیشتر فقط ورودی dialog را می‌گیرد و controller مناسب را صدا می‌زند.

## ۶. کاهش حجم بیشتر HomeScreen

بعد از فاز ۱۹، `home_screen.dart` حدوداً به ۸۴۰ خط رسید.

## فایل‌های جدید فاز ۱۹

```text
lib/application/actions/security_actions_controller.dart
lib/application/actions/backup_actions_controller.dart
lib/presentation/dialogs/security_dialogs.dart
lib/presentation/dialogs/backup_dialogs.dart
docs/PHASE_19_SECURITY_BACKUP_REFACTOR.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۲۰:

- استخراج GoalDialogs و GoalActionsController
- استخراج ReportActionsController
- جدا کردن coordinatorهای باقی‌مانده
- تست action controllerها با fake repository
- کاهش `home_screen.dart` به زیر ۶۰۰ خط
