# فاز ۲۱ اضافه شد — Debt/Allocation Actions و تست Controllerها

فاز ۲۱ ادامه refactor است و منطق بدهی، طلب و پاکت پول را از `home_screen.dart` خارج‌تر می‌کند.

## ۱. DebtActionsController

فایل جدید:

```text
lib/application/actions/debt_actions_controller.dart
```

این controller مسئول عملیات بدهی و طلب است:

- ساخت تراکنش پرداخت بدهی
- ساخت تراکنش دریافت طلب
- ثبت بدهی جدید
- ثبت پرداخت/دریافت و ایجاد تراکنش مالی مربوطه

## ۲. AllocationActionsController

فایل جدید:

```text
lib/application/actions/allocation_actions_controller.dart
```

این controller مسئول پاکت پول است:

- ساخت allocation برای بدهی
- ساخت allocation برای هزینه آینده
- ثبت پول کنار گذاشته‌شده در repository

## ۳. استفاده در HomeScreen

در `home_screen.dart` این بخش‌ها ساده‌تر شدند:

- `_openDebtDialog`
- `_openDebtPaymentDialog`
- `_openAllocationDialog`

HomeScreen دیگر مستقیماً تراکنش پرداخت بدهی یا allocation نمی‌سازد؛ این کار به controllerها منتقل شد.

## ۴. به‌روزرسانی Providerها

فایل زیر آپدیت شد:

```text
lib/app/app_providers.dart
```

Providerهای جدید:

```dart
debtActionsControllerProvider
allocationActionsControllerProvider
```

## ۵. تست جدید

فایل جدید:

```text
test/actions_controller_test.dart
```

تست‌ها بررسی می‌کنند:

- پرداخت بدهی به عنوان هزینه ساخته می‌شود.
- دریافت طلب به عنوان درآمد ساخته می‌شود.
- allocation برای پاکت بدهی درست ساخته می‌شود.

## فایل‌های جدید فاز ۲۱

```text
lib/application/actions/debt_actions_controller.dart
lib/application/actions/allocation_actions_controller.dart
test/actions_controller_test.dart
docs/PHASE_21_DEBT_ALLOCATION_ACTIONS.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
lib/app/app_providers.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۲۲:

- تبدیل HomeScreen به `ConsumerStatefulWidget`
- استفاده عملی از Riverpod providerها در HomeScreen
- ساخت fake repository برای تست actionهای async
- استخراج coordinatorهای نهایی
- کاهش HomeScreen به زیر ۶۰۰ خط
