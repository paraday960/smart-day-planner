# فاز ۳۸ اضافه شد — Stabilization Sprint و آماده‌سازی تست واقعی

فاز ۳۸ دیگر قابلیت جدید محصولی اضافه نمی‌کند؛ هدف آن پایدارسازی پروژه و آماده شدن برای اجرای واقعی روی سیستم دارای Flutter و گوشی واقعی است.

## ۱. اسکریپت Stabilization Sprint

فایل جدید:

```text
scripts/stabilization_sprint.sh
```

این اسکریپت مراحل اصلی پایدارسازی را اجرا می‌کند:

```bash
flutter doctor -v
flutter pub get
flutter pub outdated
dart format lib test
flutter analyze
flutter test --coverage
python scripts/check_coverage_min.py 30
python scripts/coverage_summary.py
flutter build apk --debug
```

## ۲. جمع‌آوری Diagnostics

فایل جدید:

```text
scripts/collect_diagnostics.sh
```

این اسکریپت خروجی‌های مهم را داخل پوشه `diagnostics/` ذخیره می‌کند:

- نسخه Flutter
- flutter doctor
- dependency tree
- خروجی analyze
- خروجی test
- فایل coverage

## ۳. مستند ریسک‌های Build

فایل جدید:

```text
docs/KNOWN_BUILD_RISKS.md
```

در این فایل ریسک‌های احتمالی build و راه‌حل‌ها نوشته شده است، مثل:

- ناسازگاری پکیج‌ها
- Permission های Android
- Info.plist در iOS
- PDF فارسی
- خطاهای CI

## ۴. برنامه تست بتا

فایل جدید:

```text
release/beta_test_plan.md
```

این فایل سناریوهای تست بتا، فرم گزارش باگ و معیار قبولی نسخه بتا را مشخص می‌کند.

## ۵. چرا فاز ۳۸ مهم است؟

تا فاز ۳۷ قابلیت‌ها، معماری و تست‌های زیادی اضافه شد. اما بدون اجرای واقعی روی Flutter و گوشی، نمی‌توان مطمئن بود همه dependencyها و permissionها بدون خطا کار می‌کنند.

فاز ۳۸ یعنی توقف توسعه قابلیت و شروع چرخه:

```text
Build → Test → Fix → Retest
```

## دستور پیشنهادی اجرای فاز ۳۸ روی سیستم واقعی

```bash
cd smart_day_planner_flutter
flutter create --platforms=android,ios .
bash scripts/stabilization_sprint.sh
```

اگر خطا رخ داد:

```bash
bash scripts/collect_diagnostics.sh
```

و فایل‌های داخل `diagnostics/` را بررسی کن.

## فایل‌های جدید فاز ۳۸

```text
scripts/stabilization_sprint.sh
scripts/collect_diagnostics.sh
docs/KNOWN_BUILD_RISKS.md
release/beta_test_plan.md
docs/PHASE_38_STABILIZATION_SPRINT.md
```

## قدم بعدی پیشنهادی

بعد از فاز ۳۸، بهتر است دیگر فاز جدید اضافه نشود تا وقتی که:

1. `flutter analyze` پاس شود.
2. `flutter test` پاس شود.
3. APK debug ساخته شود.
4. حداقل روی یک گوشی واقعی نصب و تست شود.
5. باگ‌های بحرانی رفع شوند.
