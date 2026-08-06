# فاز ۱۰ اضافه شد — آماده‌سازی انتشار، فونت فارسی، PDF فارسی و فایل‌های نصب

فاز ۱۰ برای نزدیک کردن پروژه به نسخه قابل نصب و قابل ارائه اضافه شد.

---

## ۱. فونت فارسی Vazirmatn

فونت رایگان و متن‌باز Vazirmatn به پروژه اضافه شد:

```text
assets/fonts/Vazirmatn-Regular.ttf
```

در `pubspec.yaml` هم ثبت شد و در `ThemeData` برنامه استفاده می‌شود:

```dart
fontFamily: 'Vazirmatn'
```

مزیت:

- ظاهر فارسی‌تر و حرفه‌ای‌تر
- خوانایی بهتر
- مناسب رابط کاربری ایرانی
- قابل استفاده در PDF

---

## ۲. PDF واقعی با فونت فارسی

سرویس PDF واقعی در فاز ۹ اضافه شده بود، اما در فاز ۱۰ فونت فارسی Vazirmatn به آن وصل شد.

فایل:

```text
lib/services/real_pdf_report_service.dart
```

حالا PDF از فونت فارسی داخل assets استفاده می‌کند:

```text
assets/fonts/Vazirmatn-Regular.ttf
```

---

## ۳. اشتراک‌گذاری بکاپ به صورت فایل

قبلاً بکاپ رمزنگاری‌شده به صورت متن نمایش داده می‌شد. حالا امکان ساخت فایل بکاپ و اشتراک‌گذاری آن اضافه شد.

در تب تنظیمات:

```text
اشتراک فایل بکاپ
```

با این قابلیت، بکاپ رمزنگاری‌شده در فایل ذخیره می‌شود و با Share Sheet گوشی قابل ارسال است.

---

## ۴. اسکریپت ساخت APK

پوشه جدید:

```text
scripts/
```

فایل‌ها:

```text
scripts/build_android_debug.sh
scripts/build_android_release.sh
```

برای ساخت APK دیباگ:

```bash
bash scripts/build_android_debug.sh
```

برای ساخت APK ریلیز:

```bash
bash scripts/build_android_release.sh
```

---

## ۵. قالب Permission های اندروید

پوشه جدید:

```text
android_templates/
```

فایل:

```text
android_templates/AndroidManifest_permissions.xml
```

این فایل شامل Permission های لازم است:

- میکروفون
- اینترنت
- نوتیفیکیشن
- تقویم
- سرویس تشخیص گفتار

---

## ۶. راهنمای ساخت و نصب

فایل جدید:

```text
docs/BUILD_RELEASE_GUIDE.md
```

این راهنما توضیح می‌دهد:

- چطور پوشه‌های Android/iOS را بسازی
- Permission ها را کجا اضافه کنی
- چطور APK دیباگ بسازی
- چطور APK ریلیز بسازی
- چطور روی گوشی نصب کنی

---

## فایل‌های جدید فاز ۱۰

```text
assets/fonts/Vazirmatn-Regular.ttf
scripts/build_android_debug.sh
scripts/build_android_release.sh
android_templates/AndroidManifest_permissions.xml
docs/BUILD_RELEASE_GUIDE.md
docs/PHASE_10_ADDED.md
```

## فایل‌های تغییرکرده

```text
pubspec.yaml
lib/main.dart
lib/services/real_pdf_report_service.dart
lib/screens/home_screen.dart
README.md
```

---

## نکته مهم

در این محیط Flutter نصب نیست، پس build واقعی APK اینجا اجرا نشد. اما پروژه آماده است که روی سیستم خودت با Flutter اجرا شود:

```bash
cd smart_day_planner_flutter
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

یا برای APK:

```bash
bash scripts/build_android_debug.sh
```

---

## مرحله بعدی پیشنهادی

بعد از فاز ۱۰، بهتر است به جای افزودن قابلیت جدید، یک فاز پایدارسازی انجام شود:

- اجرای `flutter analyze`
- رفع خطاهای dependency
- تست روی گوشی واقعی
- بهینه‌سازی UI
- ساخت آیکن برنامه
- تعیین package name
- آماده‌سازی keystore برای انتشار
