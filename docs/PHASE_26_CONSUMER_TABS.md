# فاز ۲۶ اضافه شد — ConsumerWidget کردن تب‌ها و استفاده مستقیم‌تر از Providerها

فاز ۲۶ ادامه فاز ۲۵ است و تمرکز آن روی تبدیل تدریجی تب‌ها به `ConsumerWidget` و خواندن داده‌ها از Riverpod داخل خود تب‌هاست.

## ۱. DashboardTab به ConsumerWidget تبدیل شد

فایل تغییرکرده:

```text
lib/presentation/dashboard/dashboard_tab.dart
```

قبل از فاز ۲۶، `DashboardTab` تعداد زیادی dependency از بیرون می‌گرفت:

- tasks
- financeRepository
- goalRepository
- plannedExpenseRepository
- debtRepository
- availabilityRepository
- dashboardController
- timeAwarePlanner

حالا خودش با `ref.watch` این موارد را می‌خواند:

```dart
taskRepositoryProvider
financeRepositoryProvider
goalRepositoryProvider
plannedExpenseRepositoryProvider
debtRepositoryProvider
availabilityRepositoryProvider
dashboardControllerProvider
timeAwarePlannerProvider
```

و constructor آن بسیار کوچک‌تر شد:

```dart
DashboardTab(
  onEdit: _openTaskForm,
  onComplete: _completeTask,
)
```

## ۲. TasksTab به ConsumerWidget تبدیل شد

فایل تغییرکرده:

```text
lib/presentation/tasks/tasks_tab.dart
```

قبل از فاز ۲۶، `TasksTab` این موارد را از بیرون می‌گرفت:

- tasks
- planner

حالا خودش از Provider می‌خواند:

```dart
taskRepositoryProvider
smartPlannerProvider
```

constructor آن هم ساده‌تر شد.

## ۳. FinanceTab شروع به استفاده از Provider کرد

فایل تغییرکرده:

```text
lib/presentation/finance/finance_tab.dart
```

`FinanceTab` به `ConsumerWidget` تبدیل شد و برای ساخت خلاصه مالی از Provider زیر استفاده می‌کند:

```dart
financeControllerProvider
```

هنوز همه dependencyهای FinanceTab حذف نشده‌اند، چون این تب بزرگ‌تر و پیچیده‌تر است. این کار باید تدریجی انجام شود.

## ۴. HomeScreen سبک‌تر شد

در `home_screen.dart` پاس دادن dependencyها به تب‌های Dashboard و Tasks کمتر شد.

اکنون تب‌های زیر واقعاً به Riverpod وصل شده‌اند:

```text
DashboardTab
TasksTab
FinanceTab، به صورت مرحله‌ای
```

## نتیجه فاز ۲۶

- تب‌ها به سمت self-contained شدن رفتند.
- constructorهای UI کوتاه‌تر شدند.
- استفاده از Providerها از سطح HomeScreen به داخل تب‌ها منتقل شد.
- مسیر تبدیل سایر تب‌ها به ConsumerWidget آماده‌تر شد.

## قدم بعدی پیشنهادی

فاز ۲۷:

- حذف dependencyهای باقی‌مانده از FinanceTab
- تبدیل AssistantTab و SettingsTab به ConsumerWidget در صورت نیاز
- ساخت Widget Test برای DashboardTab با ProviderScope overrides
- حذف بیشتر callbackهای غیرضروری از HomeScreen
