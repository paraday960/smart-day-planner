# فاز ۱۱ — پایدارسازی، تست، آماده‌سازی انتشار

فاز ۱۱ به جای اضافه کردن قابلیت بزرگ جدید، پروژه را برای تست واقعی و انتشار آماده‌تر می‌کند.

## چیزهایی که اضافه شد

### ۱. تنظیمات محصول

فایل:

```text
lib/app_config.dart
```

شامل:

- نام فارسی برنامه
- نام انگلیسی برنامه
- package name پیشنهادی
- نسخه برنامه
- توضیح حالت حریم خصوصی

### ۲. تست واحد اولیه

فایل:

```text
test/persian_format_test.dart
```

تست می‌کند:

- تبدیل اعداد انگلیسی به فارسی
- تبدیل اعداد فارسی به انگلیسی
- فرمت پول با تومان
- فرمت دقیقه

### ۳. اسکریپت بررسی سلامت پروژه

فایل:

```text
scripts/phase11_check.sh
```

این مراحل را اجرا می‌کند:

```bash
flutter --version
flutter doctor
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

### ۴. اسکریپت اصلاح فرمت

فایل:

```text
scripts/phase11_fix_format.sh
```

برای فرمت کردن کدها و اجرای analyze.

### ۵. اسکریپت راهنمای package name

فایل:

```text
scripts/prepare_android_package.sh
```

برای یادآوری تنظیم applicationId، label و permission ها.

### ۶. فایل‌های انتشار

پوشه:

```text
release/
```

شامل:

```text
privacy_policy_fa.md
store_listing_fa.md
qa_matrix.md
```

### ۷. راهنمای QA و انتشار

فایل‌های مهم:

```text
docs/BUILD_RELEASE_GUIDE.md
release/qa_matrix.md
```

## دستور پیشنهادی تست روی سیستم واقعی

```bash
cd smart_day_planner_flutter
flutter create --platforms=android,ios .
flutter pub get
bash scripts/phase11_check.sh
```

اگر خطای فرمت داشتی:

```bash
bash scripts/phase11_fix_format.sh
```

## نکته مهم

در این محیط Flutter نصب نیست، بنابراین تست واقعی build اجرا نشد. فاز ۱۱ ابزارها و فایل‌های لازم را اضافه کرده تا روی سیستم توسعه واقعی تست و پایدارسازی انجام شود.

## قدم بعدی بعد از فاز ۱۱

پیشنهاد می‌شود قبل از هر قابلیت جدید:

1. پروژه روی سیستم دارای Flutter اجرا شود.
2. خطاهای `flutter analyze` رفع شود.
3. حداقل روی یک گوشی اندرویدی واقعی تست شود.
4. خروجی APK دیباگ ساخته و نصب شود.
5. لیست QA تکمیل شود.
