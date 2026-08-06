# فاز ۳۵ اضافه شد — تست VoiceCommandProcessor، BackupActions و Coverage در CI

فاز ۳۵ روی افزایش اطمینان از بخش‌های هوشمند و مسیرهای تست خودکار تمرکز دارد.

## ۱. تست VoiceCommandProcessor

فایل جدید:

```text
test/voice_command_processor_test.dart
```

سناریوهای تست‌شده:

### گفت‌وگوی چندمرحله‌ای بدهی

```text
به ممد بدهکارم
یک میلیون تومان
تا دو روز دیگه
```

تست بررسی می‌کند که بدهی با شخص «ممد» و مبلغ ۱٬۰۰۰٬۰۰۰ تومان ثبت شود.

### اشاره‌فهمی و تأیید عملیات مبهم

```text
پونصد براش کنار بذار
تأیید
```

تست بررسی می‌کند که برنامه ابتدا تأیید بخواهد و بعد از تأیید، ۵۰۰٬۰۰۰ تومان برای بدهی ذخیره کند.

## ۲. تست BackupActionsController

فایل جدید:

```text
test/backup_actions_controller_test.dart
```

این تست بررسی می‌کند که خروجی بکاپ رمزنگاری‌شده wrapper معتبر داشته باشد:

```text
smart_day_planner_encrypted_backup
iv
data
```

## ۳. Coverage در CI

فایل تغییرکرده:

```text
.github/workflows/flutter_ci.yml
```

در workflow تست، دستور زیر جایگزین تست ساده شد:

```bash
flutter test --coverage
```

و فایل coverage به عنوان artifact آپلود می‌شود:

```text
coverage/lcov.info
```

## ۴. اصلاح VoiceCommandProcessor برای Port نوتیفیکیشن

فایل تغییرکرده:

```text
lib/services/voice_command_processor.dart
```

وابستگی نوتیفیکیشن از concrete service به Port تغییر کرد:

```dart
NotificationServicePort
```

## فایل‌های جدید فاز ۳۵

```text
test/voice_command_processor_test.dart
test/backup_actions_controller_test.dart
docs/PHASE_35_VOICE_AND_COVERAGE_TESTS.md
```

## فایل‌های تغییرکرده

```text
.github/workflows/flutter_ci.yml
lib/services/voice_command_processor.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۳۶:

- تست سناریوی کامل end-to-end با fakeها: درآمد → بدهی → پاکت → ریسک
- اضافه کردن حداقل درصد coverage قابل قبول
- گزارش coverage در Pull Request
- تست Backup restore با fake portها
