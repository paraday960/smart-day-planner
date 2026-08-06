# فاز ۳۷ اضافه شد — تست خطا، Confidence و گزارش Coverage

فاز ۳۷ ادامه فاز ۳۶ است و روی سناریوهای خطا، اعتمادسنجی فرمان‌های حساس و سخت‌گیرانه‌تر کردن CI تمرکز دارد.

## ۱. تست CommandConfidenceService

فایل جدید:

```text
test/command_confidence_service_test.dart
```

این تست بررسی می‌کند:

- مبلغ‌های بزرگ مثل ۱٬۰۰۰٬۰۰۰ تومان نیاز به تأیید دارند.
- مبلغ‌های محاوره‌ای مبهم مثل «پونصد» confidence پایین‌تری می‌گیرند و باید تأیید شوند.

## ۲. تست لغو عملیات حساس در VoiceCommandProcessor

فایل جدید:

```text
test/voice_command_confirmation_test.dart
```

سناریوهای تست‌شده:

```text
هزینه یک میلیون تومان ثبت کن
لغو
```

و:

```text
به ممد یک میلیون تومان بدهکارم تا دو روز دیگه
لغو
```

تست بررسی می‌کند عملیات تا قبل از تأیید ذخیره نشود و با «لغو» واقعاً انجام نشود.

## ۳. تست خطای رمز بکاپ

فایل جدید:

```text
test/backup_restore_error_test.dart
```

این تست بررسی می‌کند اگر بکاپ با رمز اشتباه بازیابی شود، خطا رخ دهد و برنامه آن را موفق فرض نکند.

## ۴. گزارش Coverage در CI

فایل جدید:

```text
scripts/coverage_summary.py
```

این اسکریپت از `coverage/lcov.info` یک خلاصه markdown می‌سازد:

```text
coverage/coverage-summary.md
```

## ۵. افزایش حداقل Coverage

فایل تغییرکرده:

```text
.github/workflows/flutter_ci.yml
```

حداقل coverage از ۲۰٪ به ۳۰٪ افزایش یافت:

```bash
python scripts/check_coverage_min.py 30
```

همچنین خلاصه coverage به GitHub Step Summary اضافه می‌شود و فایل‌های زیر artifact می‌شوند:

```text
coverage/lcov.info
coverage/coverage-summary.md
```

## فایل‌های جدید فاز ۳۷

```text
test/command_confidence_service_test.dart
test/voice_command_confirmation_test.dart
test/backup_restore_error_test.dart
scripts/coverage_summary.py
docs/PHASE_37_ERROR_CONFIDENCE_COVERAGE.md
```

## فایل‌های تغییرکرده

```text
.github/workflows/flutter_ci.yml
README.md
```

## قدم بعدی پیشنهادی

فاز ۳۸:

- اجرای واقعی تست‌ها روی سیستم دارای Flutter
- رفع خطاهای احتمالی compile/analyze
- تثبیت dependencyها
- ساخت APK debug و تست روی گوشی واقعی
- توقف افزودن قابلیت و ورود به چرخه bugfix
