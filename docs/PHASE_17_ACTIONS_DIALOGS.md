# فاز ۱۷ اضافه شد — استخراج Dialogها و Action Controllerها

فاز ۱۷ ادامه refactor است. هدف این فاز این است که `HomeScreen` فقط coordinator باشد و منطق عملیات و dialogهای تکراری از آن خارج شوند.

## ۱. TaskActionsController

فایل جدید:

```text
lib/application/tasks/task_actions_controller.dart
```

این controller عملیات مربوط به کارها را انجام می‌دهد:

- ذخیره کار جدید یا ویرایش‌شده
- کامل کردن کار
- بازگردانی کار
- حذف کار
- هماهنگی با نوتیفیکیشن کارها

## ۲. FinanceActionsController

فایل جدید:

```text
lib/application/finance/finance_actions_controller.dart
```

این controller عملیات مالی پرتکرار را مدیریت می‌کند:

- ثبت تراکنش
- تشخیص اینکه بعد از تکمیل کار باید درآمد پرسیده شود یا نه
- ثبت درآمد مربوط به کار کامل‌شده

## ۳. TaskDialogs

فایل جدید:

```text
lib/presentation/dialogs/task_dialogs.dart
```

شامل:

- پرسیدن زمان واقعی انجام کار
- تأیید حذف کار

## ۴. FinanceDialogs

فایل جدید:

```text
lib/presentation/dialogs/finance_dialogs.dart
```

شامل:

- پرسیدن درآمد بعد از تکمیل کار کاری
- ثبت درآمد/هزینه دستی

## ۵. استفاده عملی در HomeScreen

در `home_screen.dart` بخشی از dialogها و عملیات‌ها به فایل‌های جدید منتقل شد:

- `_askActualMinutes` حالا از `TaskDialogs` استفاده می‌کند.
- `_deleteTask` حالا از `TaskDialogs` و `TaskActionsController` استفاده می‌کند.
- `_openTransactionDialog` حالا از `FinanceDialogs` و `FinanceActionsController` استفاده می‌کند.
- `_askIncomeForCompletedWork` حالا از `FinanceDialogs` استفاده می‌کند.
- `_askSecretText` و `_showLargeText` حالا از `CommonDialogs` استفاده می‌کنند.

## فایل‌های جدید فاز ۱۷

```text
lib/application/tasks/task_actions_controller.dart
lib/application/finance/finance_actions_controller.dart
lib/presentation/dialogs/task_dialogs.dart
lib/presentation/dialogs/finance_dialogs.dart
docs/PHASE_17_ACTIONS_DIALOGS.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
README.md
```

## وضعیت باقی‌مانده

هنوز تعدادی dialog بزرگ داخل `home_screen.dart` باقی مانده‌اند:

- هدف‌های درآمدی
- تنظیم PIN
- بازیابی بکاپ
- هزینه آینده
- بدهی/طلب
- پاکت پول
- بودجه دسته‌بندی
- زمان آزاد

این‌ها می‌توانند در فازهای بعدی به dialogهای تخصصی منتقل شوند.

## قدم بعدی پیشنهادی

فاز ۱۸:

- استخراج `DebtDialogs`
- استخراج `GoalDialogs`
- استخراج `BackupDialogs`
- استخراج `SettingsDialogs`
- تست controllerها با mock repositoryها
- حذف بیشتر منطق از `home_screen.dart`
