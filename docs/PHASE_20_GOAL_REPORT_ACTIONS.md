# فاز ۲۰ اضافه شد — Goal/Report Action Controllers و تکمیل استخراج Dialogهای باقی‌مانده

فاز ۲۰ ادامه فازهای refactor است و روی خارج کردن منطق هدف‌ها، گزارش‌ها، PDF، تقویم و هشدارها از `home_screen.dart` تمرکز دارد.

## ۱. GoalActionsController

فایل جدید:

```text
lib/application/actions/goal_actions_controller.dart
```

این controller ذخیره هدف‌های هوشمند را انجام می‌دهد:

- هدف درآمد روزانه
- هدف درآمد ماه شمسی
- هدف کار عمیق روزانه

## ۲. GoalDialogs

فایل جدید:

```text
lib/presentation/dialogs/goal_dialogs.dart
```

Dialog تنظیم هدف‌ها از `home_screen.dart` خارج شد و به این فایل منتقل شد.

## ۳. ReportActionsController

فایل جدید:

```text
lib/application/actions/report_actions_controller.dart
```

این controller مسئول عملیات گزارش و خروجی است:

- خروجی CSV کارها
- خروجی CSV مالی
- گزارش متنی ماه شمسی
- گزارش HTML آماده PDF
- ساخت و اشتراک‌گذاری PDF واقعی
- پیش‌نمایش رویدادهای تقویم
- زمان‌بندی هشدارهای هوشمند

## ۴. به‌روزرسانی Providerها

فایل زیر آپدیت شد:

```text
lib/app/app_providers.dart
```

Providerهای action controllerهای جدید اضافه شدند:

- TaskActionsController
- FinanceActionsController
- SecurityActionsController
- BackupActionsController
- GoalActionsController
- ReportActionsController

## ۵. سبک‌تر شدن HomeScreen

این متدها در `home_screen.dart` ساده‌تر شدند:

- `_openGoalsDialog`
- `_exportTasksCsv`
- `_exportFinanceCsv`
- `_showMonthlyReport`
- `_showPrintablePdfReport`
- `_shareRealPdfReport`
- `_showCalendarPreview`
- `_scheduleSmartAlerts`

حالا این متدها بیشتر فقط controller مناسب را صدا می‌زنند.

## وضعیت HomeScreen

بعد از فاز ۲۰، `home_screen.dart` حدوداً به ۷۸۰ خط کاهش پیدا کرد.

## فایل‌های جدید فاز ۲۰

```text
lib/application/actions/goal_actions_controller.dart
lib/application/actions/report_actions_controller.dart
lib/presentation/dialogs/goal_dialogs.dart
docs/PHASE_20_GOAL_REPORT_ACTIONS.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
lib/app/app_providers.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۲۱:

- استخراج actionهای Debt/Allocation به controller مستقل
- تست action controllerها با fake repository
- تبدیل HomeScreen به Riverpod ConsumerStatefulWidget
- کاهش home_screen.dart به زیر ۵۰۰ خط
