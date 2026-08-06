# فاز ۲۷ اضافه شد — تکمیل Riverpod در تب‌ها و Widget Test

فاز ۲۷ ادامه فاز ۲۶ است و روی کامل‌تر کردن استفاده از Riverpod داخل تب‌ها و اضافه کردن تست Widget تمرکز دارد.

## ۱. FinanceTab بیشتر به Riverpod وصل شد

فایل تغییرکرده:

```text
lib/presentation/finance/finance_tab.dart
```

`FinanceTab` قبلاً به `ConsumerWidget` تبدیل شده بود، اما هنوز خلاصه مالی را خودش محاسبه می‌کرد. حالا از Provider زیر استفاده می‌کند:

```dart
financeControllerProvider
```

و خلاصه مالی را از `FinanceController` می‌گیرد:

```dart
final summary = ref.watch(financeControllerProvider).buildSummary(repository);
```

## ۲. حذف بخشی از dependency passing از FinanceTab

در این فاز بخشی از ورودی‌های غیرضروری FinanceTab حذف شد و سرویس‌ها/repositoryهای بیشتری از Provider خوانده می‌شوند.

FinanceTab حالا خودش از Providerها می‌خواند:

```dart
financeRepositoryProvider
goalRepositoryProvider
plannedExpenseRepositoryProvider
debtRepositoryProvider
allocationRepositoryProvider
categoryBudgetRepositoryProvider
goalPlanningServiceProvider
debtPlanningServiceProvider
envelopePlanningServiceProvider
chartInsightServiceProvider
financeControllerProvider
```

## ۳. Widget Test برای DashboardTab

فایل جدید:

```text
test/dashboard_tab_widget_test.dart
```

این تست بررسی می‌کند که `DashboardTab` با ProviderScope و overrideهای لازم render می‌شود.

## ۴. وضعیت معماری بعد از فاز ۲۷

تا اینجا این تب‌ها به Riverpod وصل شده‌اند:

- DashboardTab
- TasksTab
- FinanceTab، تا حد زیادی

HomeScreen همچنان callbackها را مدیریت می‌کند، اما داده‌ها و controllerها به تدریج به Providerها منتقل شده‌اند.

## فایل‌های تغییرکرده/جدید

```text
lib/presentation/finance/finance_tab.dart
lib/screens/home_screen.dart
lib/app/app_providers.dart
test/dashboard_tab_widget_test.dart
docs/PHASE_27_FINANCE_CONSUMER_WIDGETS.md
```

## قدم بعدی پیشنهادی

فاز ۲۸:

- حذف dependencyهای باقی‌مانده از FinanceTab
- ConsumerWidget کردن AssistantTab و SettingsTab در صورت نیاز
- ساخت widget test برای TasksTab
- تست HomeScreen با ProviderScope کامل
- شروع حذف callbackهای غیرضروری با HomeCoordinator
