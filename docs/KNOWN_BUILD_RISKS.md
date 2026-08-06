# ریسک‌های احتمالی Build و راه‌حل‌ها

این فایل برای فاز پایدارسازی ساخته شده است. چون در محیط فعلی Flutter نصب نیست، build واقعی اینجا اجرا نشده و باید روی سیستم توسعه واقعی بررسی شود.

## ۱. ناسازگاری نسخه پکیج‌ها

پکیج‌هایی که ممکن است روی نسخه Flutter/Android/iOS نیاز به تنظیم داشته باشند:

- `device_calendar`
- `flutter_local_notifications`
- `speech_to_text`
- `flutter_tts`
- `share_plus`
- `sqflite`

راه‌حل:

```bash
flutter pub outdated
flutter pub upgrade --major-versions
flutter analyze
```

البته برای انتشار بهتر است بعد از پایدار شدن، نسخه‌ها قفل و کنترل شوند.

## ۲. Permission های Android

اگر میکروفون، تقویم یا نوتیفیکیشن کار نکرد، فایل زیر را بررسی کن:

```text
android_templates/AndroidManifest_permissions.xml
```

و Permissionها را در `android/app/src/main/AndroidManifest.xml` قرار بده.

## ۳. iOS Info.plist

برای iOS باید توضیحات دسترسی‌ها اضافه شود:

- میکروفون
- Speech Recognition
- Calendar

نمونه در:

```text
docs/BUILD_RELEASE_GUIDE.md
```

## ۴. PDF فارسی

فونت Vazirmatn اضافه شده است، اما اگر PDF در برخی دستگاه‌ها مشکل داشت:

- مطمئن شو asset فونت در `pubspec.yaml` ثبت شده است.
- `flutter clean` و `flutter pub get` را اجرا کن.

## ۵. خطاهای GitHub Actions

اگر CI fail شد:

1. ابتدا artifact لاگ را ببین.
2. `flutter analyze` را محلی اجرا کن.
3. `dart format lib test` را اجرا کن.
4. اگر coverage کمتر از ۳۰٪ بود، تست اضافه کن یا threshold را موقتاً کاهش بده.

## ۶. ساختار Platform Folders

اگر پوشه Android/iOS وجود ندارد:

```bash
flutter create --platforms=android,ios .
```

بعد permissionها و تنظیمات package name را دوباره اعمال کن.
