# فاز ۳۴ اضافه شد — Fake Platform Services و تست ActionControllerها

فاز ۳۴ ادامه فاز ۳۳ است. در فاز ۳۳ برای سرویس‌های وابسته به پلتفرم Port تعریف شد. در فاز ۳۴ برای این Portها fake implementation ساخته شد تا بتوان منطق application را بدون گوشی، تقویم واقعی، نوتیفیکیشن واقعی یا Share Sheet تست کرد.

## ۱. Fake Platform Services

فایل جدید:

```text
test/fakes/fake_platform_services.dart
```

Fakeهای اضافه‌شده:

```dart
FakeNotificationService
FakeCalendarService
FakeShareFileService
FakeVoiceResponseService
```

این fakeها برای تست استفاده می‌شوند و به سرویس واقعی گوشی وابسته نیستند.

## ۲. تست TaskActionsController با FakeNotificationService

فایل جدید:

```text
test/task_actions_controller_test.dart
```

این تست‌ها بررسی می‌کنند:

- ذخیره کار باعث schedule شدن یادآوری می‌شود.
- کامل کردن کار باعث done شدن کار و cancel شدن یادآوری می‌شود.

بدون استفاده از `flutter_local_notifications` واقعی.

## ۳. تست ReportActionsController با FakeCalendarService

فایل جدید:

```text
test/report_actions_controller_test.dart
```

این تست‌ها بررسی می‌کنند:

- پیش‌نمایش تقویم از fake calendar event ساخته می‌شود.
- اگر دسترسی تقویم وجود نداشته باشد، پیام مناسب نمایش داده می‌شود.

بدون نیاز به تقویم واقعی گوشی.

## ۴. نتیجه فاز ۳۴

اکنون بخشی از application layer بدون پلتفرم واقعی قابل تست است:

```text
TaskActionsController → FakeNotificationService
ReportActionsController → FakeCalendarService / FakeShareFileService
Voice flows → FakeVoiceResponseService آماده تست‌های بعدی
```

## فایل‌های جدید فاز ۳۴

```text
test/fakes/fake_platform_services.dart
test/task_actions_controller_test.dart
test/report_actions_controller_test.dart
docs/PHASE_34_FAKE_PLATFORM_TESTS.md
```

## قدم بعدی پیشنهادی

فاز ۳۵:

- تست VoiceCommandProcessor با fake repositoryها
- تست سناریوی کامل: ثبت بدهی → کنار گذاشتن پول → پرسیدن ریسک
- تست BackupActionsController با fake repositoryها
- راه‌اندازی coverage report در CI
