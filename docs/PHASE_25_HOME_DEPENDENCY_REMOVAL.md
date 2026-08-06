# فاز ۲۵ اضافه شد — حذف dependencyهای دستی از HomeScreen

فاز ۲۵ ادامه فاز ۲۴ است. در فاز ۲۴ `SmartDayPlannerRoot` ساخته شد و repositoryها را از Riverpod می‌خواند. در فاز ۲۵ خود `HomeScreen` هم از constructorهای شلوغ پاک شد و dependencyهایش را مستقیم از Riverpod می‌گیرد.

## ۱. HomeScreen بدون constructor شلوغ

قبل از فاز ۲۵، `HomeScreen` این همه ورودی می‌گرفت:

```dart
TaskRepository
FinanceRepository
GoalRepository
PlannedExpenseRepository
DebtRepository
AllocationRepository
CategoryBudgetRepository
AvailabilityRepository
ConversationMemoryService
NotificationService
VoiceResponseService
SecurityService
```

بعد از فاز ۲۵:

```dart
const HomeScreen()
```

## ۲. خواندن dependencyها با ref.read

داخل `_HomeScreenState` همه dependencyها از Provider خوانده می‌شوند:

```dart
_repository = ref.read(taskRepositoryProvider);
_financeRepository = ref.read(financeRepositoryProvider);
_goalRepository = ref.read(goalRepositoryProvider);
...
```

## ۳. SmartDayPlannerRoot ساده‌تر شد

فایل:

```text
lib/app/smart_day_planner_root.dart
```

حالا فقط قفل برنامه را با `securityServiceProvider` می‌سازد و سپس:

```dart
child: const HomeScreen()
```

## ۴. نتیجه معماری

مسیر dependencyها حالا این است:

```text
main.dart
  -> ساخت و load repositoryها
  -> ProviderScope overrides
  -> SmartDayPlannerRoot
  -> HomeScreen
  -> ref.read/ref.watch providerها
```

این یعنی UI اصلی دیگر constructor سنگین ندارد و برای تست widget راحت‌تر می‌شود.

## ۵. مزیت‌ها

- constructor تمیزتر
- تست‌پذیری بهتر با ProviderScope overrides
- جداسازی بهتر dependencyها از UI
- آماده‌سازی برای ConsumerWidget کردن تب‌ها
- کاهش coupling بین main.dart و صفحه‌ها

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
lib/app/smart_day_planner_root.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۲۶:

- تبدیل تب‌های `DashboardTab`, `FinanceTab`, `TasksTab`, `AssistantTab`, `SettingsTab` به ConsumerWidget
- حذف پاس دادن repositoryها از Root به تب‌ها
- استفاده مستقیم از providerها داخل هر تب
- ساخت widget test برای HomeScreen با ProviderScope override
