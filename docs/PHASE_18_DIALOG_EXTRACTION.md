# فاز ۱۸ اضافه شد — استخراج Dialogهای مالی/برنامه‌ریزی و تکمیل Action Refactor

فاز ۱۸ ادامه فاز ۱۷ است. هدف این فاز این است که dialogهای بزرگ مربوط به برنامه‌ریزی مالی، بدهی، پاکت پول، بودجه و زمان آزاد از `home_screen.dart` خارج شوند.

## ۱. PlanningDialogs

فایل جدید:

```text
lib/presentation/dialogs/planning_dialogs.dart
```

این فایل چند dialog و input model دارد:

```dart
PlannedExpenseInput
DebtInput
AllocationInput
CategoryBudgetInput
AvailabilityInput
PlanningDialogs
```

## ۲. Dialogهای منتقل‌شده

این dialogها از `home_screen.dart` به `PlanningDialogs` منتقل یا wrap شدند:

- ثبت هزینه آینده
- ثبت بدهی/طلب
- ثبت مبلغ پرداخت بدهی یا دریافت طلب
- کنار گذاشتن پول برای پاکت‌ها
- تنظیم بودجه دسته‌بندی
- تنظیم زمان آزاد و پنجره کاری

## ۳. ساده‌تر شدن HomeScreen

در `home_screen.dart` این متدها حالا فقط نقش coordinator دارند:

```dart
_openPlannedExpenseDialog
_openDebtDialog
_openDebtPaymentDialog
_openAllocationDialog
_openCategoryBudgetDialog
_openAvailabilityDialog
```

یعنی UI جزئی dialogها در فایل جدا قرار گرفته و HomeScreen فقط نتیجه را دریافت و در repository ذخیره می‌کند.

## ۴. وضعیت home_screen.dart

حجم فایل `home_screen.dart` بعد از فاز ۱۸ به حدود ۹۰۰ خط کاهش پیدا کرد. هنوز بزرگ است، اما نسبت به قبل بسیار سبک‌تر شده و تب‌ها و dialogهای اصلی جدا شده‌اند.

## ۵. ساختار dialogها بعد از فاز ۱۸

```text
lib/presentation/dialogs/
  common_dialogs.dart
  task_dialogs.dart
  finance_dialogs.dart
  planning_dialogs.dart
```

## فایل‌های جدید فاز ۱۸

```text
lib/presentation/dialogs/planning_dialogs.dart
docs/PHASE_18_DIALOG_EXTRACTION.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۱۹:

- استخراج dialogهای امنیت و بکاپ به `security_dialogs.dart` و `backup_dialogs.dart`
- ساخت `BackupActionsController`
- ساخت `DebtActionsController`
- تست action controller ها با repository fake
- تبدیل HomeScreen به coordinator زیر ۵۰۰ خط
