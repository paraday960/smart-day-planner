# فاز ۳۹ اضافه شد — Release Candidate Hardening و Feature Flags

فاز ۳۹ برای آماده‌سازی نسخه Release Candidate اضافه شد. هدف این فاز اضافه کردن قابلیت جدید نیست؛ هدف این است که اگر بعضی قابلیت‌های پلتفرمی در build یا تست گوشی مشکل ایجاد کردند، بتوانیم آن‌ها را موقتاً خاموش کنیم و نسخه پایدارتر بسازیم.

## ۱. Feature Flags

فایل جدید:

```text
lib/app/feature_flags.dart
```

قابلیت‌های قابل کنترل با `--dart-define`:

```text
ENABLE_VOICE_INPUT
ENABLE_VOICE_RESPONSE
ENABLE_CALENDAR
ENABLE_PDF_EXPORT
ENABLE_SHARE_FILES
ENABLE_SMART_NOTIFICATIONS
ENABLE_ENCRYPTED_BACKUP
```

مثال:

```bash
flutter run --dart-define=ENABLE_CALENDAR=false
```

## ۲. تست Feature Flags

فایل جدید:

```text
test/feature_flags_test.dart
```

این تست بررسی می‌کند map تنظیمات feature flagها قابل خواندن است.

## ۳. Build امن برای عیب‌یابی

فایل جدید:

```text
scripts/build_safe_debug.sh
```

این اسکریپت APK دیباگ را با خاموش کردن قابلیت‌های پرریسک می‌سازد:

```bash
bash scripts/build_safe_debug.sh
```

اگر build معمولی خطا داد ولی build safe موفق بود، احتمالاً مشکل از یکی از قابلیت‌های پلتفرمی مثل تقویم، PDF/Share یا نوتیفیکیشن است.

## ۴. Dependency Audit

فایل جدید:

```text
scripts/dependency_audit.sh
```

این اسکریپت dependencyها را بررسی و گزارش را در `diagnostics/` ذخیره می‌کند.

## ۵. چک‌لیست Release Candidate

فایل جدید:

```text
release/release_candidate_checklist.md
```

این چک‌لیست مشخص می‌کند قبل از انتشار نسخه RC چه چیزهایی باید تست شوند.

## فایل‌های جدید فاز ۳۹

```text
lib/app/feature_flags.dart
test/feature_flags_test.dart
scripts/build_safe_debug.sh
scripts/dependency_audit.sh
release/release_candidate_checklist.md
docs/PHASE_39_RELEASE_CANDIDATE_HARDENING.md
```

## قدم بعدی پیشنهادی

بعد از فاز ۳۹، بهتر است واقعاً وارد تست روی سیستم Flutter شویم و قابلیت جدید اضافه نکنیم تا خروجی APK پایدار ساخته شود.
