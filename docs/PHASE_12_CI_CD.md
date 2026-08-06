# فاز ۱۲ اضافه شد — CI/CD، مدیریت نسخه و فرآیند توسعه تیمی

فاز ۱۲ پروژه را برای توسعه جدی‌تر، همکاری تیمی و build خودکار آماده می‌کند.

## چیزهایی که اضافه شد

### ۱. GitHub Actions CI

فایل:

```text
.github/workflows/flutter_ci.yml
```

این workflow روی push و pull request اجرا می‌شود و این کارها را انجام می‌دهد:

- نصب Flutter
- دریافت dependency ها
- بررسی فرمت
- analyze
- test
- build APK دیباگ
- آپلود APK دیباگ به عنوان artifact

### ۲. Workflow ساخت خروجی Android

فایل:

```text
.github/workflows/release_android.yml
```

به صورت دستی قابل اجراست و می‌تواند بسازد:

- APK release
- Android App Bundle

### ۳. قالب Pull Request

فایل:

```text
.github/pull_request_template.md
```

برای اینکه هر تغییر با چک‌لیست تست و توضیح وارد شود.

### ۴. قالب Issue

فایل‌ها:

```text
.github/ISSUE_TEMPLATE/bug_report.yml
.github/ISSUE_TEMPLATE/feature_request.yml
```

برای گزارش باگ و درخواست قابلیت.

### ۵. Changelog

فایل:

```text
CHANGELOG.md
```

برای ثبت تغییرات نسخه‌ها.

### ۶. اسکریپت افزایش نسخه

فایل:

```text
scripts/bump_version.py
```

مثال:

```bash
python scripts/bump_version.py patch
```

### ۷. راهنمای CI/CD

فایل:

```text
docs/CI_CD_GUIDE.md
```

## نتیجه فاز ۱۲

پروژه حالا فقط یک نمونه کد نیست؛ ساختار توسعه حرفه‌ای‌تری دارد:

- تست خودکار
- build خودکار
- artifact خروجی
- روند Pull Request
- مدیریت issue
- changelog
- مدیریت نسخه

## قدم بعدی پیشنهادی

فاز ۱۳ می‌تواند روی «معماری تمیزتر و refactor» تمرکز کند:

- جدا کردن UI از منطق business
- اضافه کردن Riverpod یا Bloc
- تست سرویس‌های مالی و مکالمه‌ای
- mock repository ها
- ساده‌تر کردن `home_screen.dart`
