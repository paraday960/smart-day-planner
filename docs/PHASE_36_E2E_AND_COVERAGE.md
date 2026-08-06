# فاز ۳۶ اضافه شد — تست سناریوی کامل، Backup Restore و حداقل Coverage

فاز ۳۶ ادامه فاز ۳۵ است و روی تست‌های end-to-end هوشمند، تست بازیابی بکاپ و سخت‌گیرانه‌تر کردن CI تمرکز دارد.

## ۱. تست سناریوی کامل هوشمند

فایل جدید:

```text
test/e2e_smart_flow_test.dart
```

سناریوی تست‌شده:

```text
به ممد بدهکارم
یک میلیون تومان
تا دو روز دیگه
پونصد براش کنار بذار
تأیید
ریسک مالی دارم؟
```

این تست بررسی می‌کند:

- گفت‌وگوی چندمرحله‌ای بدهی کار کند.
- بدهی با مبلغ درست ثبت شود.
- اشاره «براش» به بدهی قبلی وصل شود.
- برای مبلغ مبهم تأیید گرفته شود.
- بعد از تأیید، پاکت پول ساخته شود.
- ریسک مالی قابل پرسیدن باشد.

## ۲. تست Backup Restore

فایل جدید:

```text
test/backup_restore_actions_test.dart
```

این تست با fake repositoryها بررسی می‌کند:

- بکاپ رمزنگاری‌شده ساخته شود.
- بکاپ در repositoryهای خالی بازیابی شود.
- کارها، تراکنش‌ها، بدهی‌ها و هدف‌ها درست برگردند.

## ۳. Fake Repositoryهای مشترک

فایل جدید:

```text
test/fakes/fake_repositories.dart
```

این fakeها برای تست‌های آینده قابل استفاده‌اند:

- FakeTaskRepository
- FakeFinanceRepository
- FakeDebtRepository
- FakeAllocationRepository
- FakeGoalRepository
- FakePlannedExpenseRepository
- FakeCategoryBudgetRepository

## ۴. حداقل Coverage در CI

فایل جدید:

```text
scripts/check_coverage_min.py
```

این اسکریپت فایل زیر را می‌خواند:

```text
coverage/lcov.info
```

و درصد پوشش تست را محاسبه می‌کند. در CI حداقل فعلی روی ۲۰٪ تنظیم شده است.

## ۵. آپدیت GitHub Actions

فایل تغییرکرده:

```text
.github/workflows/flutter_ci.yml
```

حالا CI این کارها را انجام می‌دهد:

```bash
flutter test --coverage
python scripts/check_coverage_min.py 20
```

اگر coverage کمتر از حد مجاز باشد، CI fail می‌شود.

## فایل‌های جدید فاز ۳۶

```text
test/e2e_smart_flow_test.dart
test/backup_restore_actions_test.dart
test/fakes/fake_repositories.dart
scripts/check_coverage_min.py
docs/PHASE_36_E2E_AND_COVERAGE.md
```

## فایل‌های تغییرکرده

```text
.github/workflows/flutter_ci.yml
README.md
```

## قدم بعدی پیشنهادی

فاز ۳۷:

- تست سناریوهای شکست و خطا، مثل رمز بکاپ اشتباه
- تست command confidence برای عملیات مالی حساس
- افزایش threshold پوشش تست به ۳۰٪
- گزارش coverage در Pull Request به صورت comment
