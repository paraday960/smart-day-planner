# راهنمای ساخت نسخه قابل نصب — فاز ۱۰

این راهنما برای تبدیل پروژه به APK قابل نصب روی گوشی است.

## ۱. ساخت ساختار پلتفرم‌ها

اگر هنوز پوشه‌های `android` و `ios` ساخته نشده‌اند:

```bash
cd smart_day_planner_flutter
flutter create --platforms=android,ios .
flutter pub get
```

## ۲. اضافه کردن Permission های اندروید

محتوای فایل زیر را در `android/app/src/main/AndroidManifest.xml` قبل از تگ `<application>` قرار بده:

```text
android_templates/AndroidManifest_permissions.xml
```

Permission های مهم:

- میکروفون برای فرمان صوتی
- اینترنت برای تشخیص گفتار آنلاین رایگان گوشی
- نوتیفیکیشن
- تقویم گوشی

## ۳. اضافه کردن توضیحات iOS

در `ios/Runner/Info.plist` اضافه کن:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>برای دریافت فرمان صوتی فارسی به میکروفون نیاز داریم.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>برای تبدیل گفتار فارسی به متن و اجرای فرمان‌ها استفاده می‌شود.</string>
<key>NSCalendarsUsageDescription</key>
<string>برای نمایش رویدادهای تقویم و هماهنگ کردن برنامه روزانه استفاده می‌شود.</string>
```

## ۴. ساخت APK دیباگ برای تست سریع

```bash
bash scripts/build_android_debug.sh
```

خروجی:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## ۵. ساخت APK انتشار

```bash
bash scripts/build_android_release.sh
```

خروجی:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## ۶. نصب روی گوشی اندروید

گوشی را با USB وصل کن و USB debugging را فعال کن:

```bash
flutter devices
flutter install
```

یا APK را مستقیم روی گوشی کپی و نصب کن.

## ۷. نکته مهم درباره امضا برای انتشار عمومی

برای انتشار در مارکت‌ها باید APK/AAB را امضا کنی. برای تست شخصی، APK دیباگ کافی است.

## ۸. فونت فارسی

فونت Vazirmatn به پروژه اضافه شده:

```text
assets/fonts/Vazirmatn-Regular.ttf
```

این فونت هم در UI برنامه و هم در PDF استفاده می‌شود.

## ۹. محدودیت‌های باقی‌مانده

- برای PDF کاملاً حرفه‌ای‌تر می‌توان صفحه‌بندی و طراحی گرافیکی بهتر اضافه کرد.
- برای تقویم، مرحله بعد اتصال رویدادهای تقویم به برنامه‌ریز روزانه است.
- برای مارکت، باید آیکن، نام پکیج، نسخه‌بندی و امضا نهایی شود.
