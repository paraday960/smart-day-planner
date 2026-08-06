# فاز ۹ اضافه شد — تقویم واقعی، هشدار زمان‌بندی‌شده، PDF واقعی و اشتراک‌گذاری

فاز ۹ برنامه را برای استفاده نزدیک‌تر به نسخه انتشار آماده می‌کند.

---

## ۱. اتصال به تقویم گوشی

سرویس جدید:

```text
lib/services/calendar_service.dart
```

قابلیت‌ها:

- درخواست دسترسی تقویم
- خواندن رویدادهای ۷ روز آینده
- امکان ساخت رویداد یادآوری در تقویم گوشی

پکیج اضافه‌شده:

```yaml
device_calendar: ^4.3.3
```

در تب تنظیمات دکمه «تقویم گوشی» اضافه شده است.

---

## ۲. زمان‌بندی هشدارهای هوشمند

سرویس جدید:

```text
lib/services/smart_notification_scheduler.dart
```

این سرویس هشدارهای ساخته‌شده توسط `SmartNotificationAdvisor` را برای فردا صبح زمان‌بندی می‌کند.

نمونه هشدار:

```text
فقط ۲ روز تا بدهی ممد مانده و ۷۰۰٬۰۰۰ تومان کم داری.
```

---

## ۳. PDF واقعی

سرویس جدید:

```text
lib/services/real_pdf_report_service.dart
```

این سرویس با پکیج `pdf` فایل PDF واقعی می‌سازد.

پکیج اضافه‌شده:

```yaml
pdf: ^3.11.1
```

نکته: برای نمایش فارسی کاملاً استاندارد در PDF نهایی، مرحله بعد بهتر است فونت فارسی مثل Vazirmatn را در assets قرار بدهیم و داخل PDF استفاده کنیم.

---

## ۴. ذخیره و اشتراک‌گذاری فایل

سرویس جدید:

```text
lib/services/share_file_service.dart
```

قابلیت‌ها:

- ذخیره فایل در حافظه برنامه
- اشتراک‌گذاری فایل با Share Sheet گوشی

پکیج‌های اضافه‌شده:

```yaml
path_provider: ^2.1.4
share_plus: ^10.0.2
```

---

## ۵. تغییرات UI

در تب تنظیمات اضافه شد:

- تقویم گوشی
- زمان‌بندی هشدار
- PDF واقعی و اشتراک‌گذاری
- HTML آماده PDF همچنان باقی مانده است

---

## Permission های لازم

### Android
بعد از `flutter create` در `AndroidManifest.xml` بسته به نسخه اندروید و پکیج تقویم، این دسترسی‌ها لازم می‌شود:

```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### iOS
در `Info.plist`:

```xml
<key>NSCalendarsUsageDescription</key>
<string>برای نمایش رویدادهای تقویم و هماهنگ کردن برنامه روزانه استفاده می‌شود.</string>
```

---

## فایل‌های جدید

```text
lib/services/calendar_service.dart
lib/services/real_pdf_report_service.dart
lib/services/share_file_service.dart
lib/services/smart_notification_scheduler.dart
```

## فایل‌های تغییرکرده

```text
pubspec.yaml
lib/services/notification_service.dart
lib/screens/home_screen.dart
README.md
```

## مرحله بعدی پیشنهادی

فاز ۱۰ می‌تواند شامل این‌ها باشد:

- اضافه کردن فونت فارسی Vazirmatn به PDF
- همگام‌سازی کامل رویدادهای تقویم با برنامه روزانه
- اشتراک‌گذاری بکاپ رمزنگاری‌شده به صورت فایل واقعی
- نوتیفیکیشن‌های پویا بر اساس تغییر درآمد روزانه
- آماده‌سازی خروجی APK و راهنمای نصب روی گوشی
