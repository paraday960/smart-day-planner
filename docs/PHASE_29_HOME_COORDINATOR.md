# فاز ۲۹ اضافه شد — HomeCoordinator و سبک‌تر شدن HomeScreen

فاز ۲۹ ادامه فازهای refactor است و هدف آن کم کردن callbackها و عملیات مستقیم داخل `HomeScreen` است.

## ۱. HomeCoordinator

فایل جدید:

```text
lib/application/home/home_coordinator.dart
```

این کلاس بین UI و action controllerها/repositoryها قرار می‌گیرد و عملیات پرتکرار صفحه اصلی را هماهنگ می‌کند.

## ۲. مسئولیت‌های HomeCoordinator

`HomeCoordinator` این عملیات را متمرکز می‌کند:

- ذخیره کار جدید یا ویرایش‌شده
- کامل کردن کار
- بازگردانی کار
- حذف کار
- ثبت تراکنش مالی
- ذخیره هدف‌های درآمدی
- ثبت هزینه آینده
- ثبت بدهی/طلب
- ثبت پرداخت بدهی یا دریافت طلب
- کنار گذاشتن پول برای پاکت‌ها
- ذخیره بودجه دسته‌بندی
- ذخیره تنظیمات زمان آزاد
- تنظیم/حذف رمز از طریق controller امنیتی
- ساخت و بازیابی بکاپ رمزنگاری‌شده

## ۳. Provider جدید

فایل تغییرکرده:

```text
lib/app/app_providers.dart
```

Provider جدید:

```dart
homeCoordinatorProvider
```

این Provider از repositoryها و action controllerهای موجود یک `HomeCoordinator` می‌سازد.

## ۴. استفاده در HomeScreen

فایل تغییرکرده:

```text
lib/screens/home_screen.dart
```

حالا HomeScreen در `initState` این را می‌خواند:

```dart
_homeCoordinator = ref.read(homeCoordinatorProvider);
```

و بسیاری از عملیات قبلی را به آن واگذار می‌کند.

نمونه:

```dart
await _homeCoordinator.saveTask(result, isNew: task == null);
await _homeCoordinator.completeTask(task, actual);
await _homeCoordinator.addDebt(input);
await _homeCoordinator.allocate(...);
```

## ۵. کاهش حجم HomeScreen

بعد از فاز ۲۹، `home_screen.dart` به حدود ۶۷۰ خط رسید.

## ۶. مزیت معماری

قبل از این فاز، HomeScreen هنوز مستقیم چندین action controller را صدا می‌زد. حالا این کارها پشت یک coordinator قرار گرفتند.

مزیت‌ها:

- کاهش وابستگی مستقیم UI به controllerهای متعدد
- ساده‌تر شدن تست منطق هماهنگی در آینده
- آماده‌سازی برای حذف callbackهای باقی‌مانده
- نزدیک‌تر شدن HomeScreen به یک coordinator سبک UI

## فایل‌های جدید فاز ۲۹

```text
lib/application/home/home_coordinator.dart
docs/PHASE_29_HOME_COORDINATOR.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
lib/app/app_providers.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۳۰:

- انتقال callbackهای باقی‌مانده از HomeScreen به HomeCoordinator
- ساخت تست واحد برای HomeCoordinator با fake repositoryها
- ایجاد interface برای repositoryها جهت mock بهتر
- کاهش `home_screen.dart` به زیر ۵۰۰ خط
