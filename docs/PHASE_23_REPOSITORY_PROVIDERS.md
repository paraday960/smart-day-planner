# فاز ۲۳ اضافه شد — Repository Providers و تست override با Riverpod

فاز ۲۳ ادامه فاز ۲۲ است و وابستگی‌های اصلی برنامه را به Riverpod نزدیک‌تر می‌کند. تا قبل از این، Providerها بیشتر برای controllerها بودند؛ حالا repositoryها و سرویس‌های اصلی هم Provider دارند.

## ۱. Provider برای Repositoryها

فایل تغییرکرده:

```text
lib/app/app_providers.dart
```

Providerهای جدید:

```dart
taskRepositoryProvider
financeRepositoryProvider
goalRepositoryProvider
plannedExpenseRepositoryProvider
debtRepositoryProvider
allocationRepositoryProvider
categoryBudgetRepositoryProvider
availabilityRepositoryProvider
conversationMemoryServiceProvider
notificationServiceProvider
voiceResponseServiceProvider
securityServiceProvider
```

## ۲. Override کردن Providerها در main.dart

فایل تغییرکرده:

```text
lib/main.dart
```

تابع زیر اضافه و استفاده شد:

```dart
buildAppOverrides(...)
```

در `ProviderScope`، repositoryهای initialize شده به Providerها تزریق می‌شوند.

## ۳. آماده‌سازی برای حذف dependencyهای دستی

هنوز `HomeScreen` برای سازگاری، repositoryها را از constructor دریافت می‌کند؛ اما از این فاز به بعد همان نمونه‌ها داخل Riverpod هم در دسترس هستند.

این یعنی در فازهای بعدی می‌توانیم:

- پاس دادن دستی repositoryها به constructor را حذف کنیم
- تب‌ها را به `ConsumerWidget` تبدیل کنیم
- repositoryها را با `ref.watch(...)` بخوانیم
- در تست‌ها providerها را با fake override کنیم

## ۴. تست Provider Override

فایل جدید:

```text
test/provider_smoke_test.dart
```

این تست بررسی می‌کند:

- Providerهای repository قابل override هستند
- Providerهای action controller قابل خواندن هستند

## ۵. نتیجه فاز ۲۳

پروژه یک قدم دیگر به معماری قابل تست و production-ready نزدیک شد:

- وابستگی‌ها در Riverpod ثبت شدند
- main.dart از overrides استفاده می‌کند
- تست‌ها می‌توانند dependencyها را جایگزین کنند
- مسیر حذف constructorهای شلوغ آماده شد

## قدم بعدی پیشنهادی

فاز ۲۴:

- حذف تدریجی repositoryها از constructor `HomeScreen`
- تبدیل تب‌ها به `ConsumerWidget`
- استفاده از `ref.watch(repositoryProvider)` در تب‌ها
- ساخت `HomeCoordinator` یا `HomeController`
- کاهش constructorهای بلند در UI
