# فاز ۳۳ اضافه شد — Platform Service Ports و تست‌پذیری سرویس‌های سیستمی

فاز ۳۳ ادامه فاز ۳۲ است. در فاز ۳۲ repositoryها به Portها وصل شدند؛ در فاز ۳۳ سرویس‌های وابسته به پلتفرم مثل نوتیفیکیشن، تقویم، اشتراک‌گذاری فایل و پاسخ صوتی هم Port گرفتند.

## ۱. Portهای جدید برای سرویس‌های پلتفرم

پوشه:

```text
lib/domain/services/
```

فایل‌های جدید:

```text
notification_service_port.dart
calendar_service_port.dart
share_file_service_port.dart
voice_response_port.dart
```

این Portها باعث می‌شوند application layer بتواند بدون وابستگی مستقیم به Flutter platform services تست شود.

## ۲. پیاده‌سازی Portها توسط سرویس‌های واقعی

فایل‌های تغییرکرده:

```text
lib/services/notification_service.dart
lib/services/calendar_service.dart
lib/services/share_file_service.dart
lib/services/voice_response_service.dart
```

حالا این سرویس‌ها interfaceهای مربوطه را implement می‌کنند.

## ۳. جدا شدن مدل‌های پلتفرمی از سرویس‌ها

برای جلوگیری از وابستگی domain به service، مدل‌های زیر جدا شدند:

```text
lib/models/calendar_event_summary.dart
lib/models/assistant_voice_gender.dart
```

## ۴. TaskActionsController و HomeCoordinator از NotificationServicePort استفاده می‌کنند

فایل‌های تغییرکرده:

```text
lib/application/tasks/task_actions_controller.dart
lib/application/home/home_coordinator.dart
```

این یعنی عملیات کارها دیگر به `NotificationService` concrete وابسته نیست و می‌تواند با fake notification service تست شود.

## ۵. ReportActionsController از Portهای پلتفرم استفاده می‌کند

فایل تغییرکرده:

```text
lib/application/actions/report_actions_controller.dart
```

این controller حالا برای تقویم و اشتراک‌گذاری فایل از Port استفاده می‌کند:

```dart
CalendarServicePort
ShareFileServicePort
```

## ۶. Providerهای جدید برای سرویس‌های پلتفرم

فایل تغییرکرده:

```text
lib/app/app_providers.dart
```

Providerهای جدید/به‌روزشده:

```dart
notificationServiceProvider // حالا NotificationServicePort
calendarServiceProvider
shareFileServiceProvider
voiceResponseServiceProvider // حالا VoiceResponsePort
```

## نتیجه فاز ۳۳

حالا وابستگی به پلتفرم پشت interfaceها پنهان شده است:

```text
Application Layer → Platform Service Ports → Flutter/Device Implementations
```

این برای تست، توسعه تیمی و آماده‌سازی معماری production بسیار مهم است.

## قدم بعدی پیشنهادی

فاز ۳۴:

- ساخت FakeNotificationService و FakeShareFileService برای تست‌ها
- تست TaskActionsController با fake notification
- تست ReportActionsController با fake calendar/share
- حذف وابستگی‌های concrete باقی‌مانده از application layer
