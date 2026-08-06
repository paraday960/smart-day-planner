# راهنمای CI/CD — فاز ۱۲

این پروژه حالا برای اجرای خودکار تست و build در GitHub Actions آماده است.

## workflow ها

```text
.github/workflows/flutter_ci.yml
.github/workflows/release_android.yml
```

## Flutter CI

روی push و pull request اجرا می‌شود:

- checkout
- نصب Java 17
- نصب Flutter stable
- `flutter create --platforms=android,ios .`
- `flutter pub get`
- بررسی فرمت
- `flutter analyze`
- `flutter test`
- ساخت APK دیباگ
- آپلود APK دیباگ به عنوان artifact

## Android Release Build

به صورت دستی از GitHub Actions اجرا می‌شود و خروجی می‌تواند:

- APK release
- AAB release

باشد.

## نکته درباره امضای release

workflow فعلی release را بدون keystore اختصاصی می‌سازد. برای انتشار در مارکت باید secrets زیر اضافه شوند و signingConfig تنظیم شود:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

## قالب PR و Issue

اضافه شد:

```text
.github/pull_request_template.md
.github/ISSUE_TEMPLATE/bug_report.yml
.github/ISSUE_TEMPLATE/feature_request.yml
```

## افزایش نسخه

اسکریپت:

```bash
python scripts/bump_version.py patch
python scripts/bump_version.py minor
python scripts/bump_version.py major
```

## پیشنهاد روند انتشار

1. یک branch جدید بساز.
2. تغییرات را push کن.
3. Pull Request باز کن.
4. صبر کن CI سبز شود.
5. نسخه را bump کن.
6. `CHANGELOG.md` را آپدیت کن.
7. workflow release را دستی اجرا کن.
8. APK/AAB artifact را دانلود و روی گوشی تست کن.
