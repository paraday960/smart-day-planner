# فاز ۲۴ اضافه شد — تزریق Repositoryها از Riverpod و سبک‌تر شدن main.dart

فاز ۲۴ ادامه فاز ۲۳ است. در فاز ۲۳ Providerهای repository ساخته شدند؛ در فاز ۲۴ این Providerها وارد ساختار اصلی برنامه شدند و `main.dart` از پاس دادن مستقیم dependencyها به UI فاصله گرفت.

## ۱. SmartDayPlannerRoot

فایل جدید:

```text
lib/app/smart_day_planner_root.dart
```

این کلاس یک `ConsumerWidget` است و repositoryها و سرویس‌های اصلی را از Riverpod می‌خواند:

```dart
ref.watch(taskRepositoryProvider)
ref.watch(financeRepositoryProvider)
ref.watch(goalRepositoryProvider)
...
```

سپس آن‌ها را به `HomeScreen` می‌دهد.

## ۲. ساده‌تر شدن SmartDayPlannerApp

قبل از فاز ۲۴، `SmartDayPlannerApp` تعداد زیادی ورودی داشت:

- TaskRepository
- FinanceRepository
- GoalRepository
- DebtRepository
- AllocationRepository
- SecurityService
- و ...

بعد از فاز ۲۴، `SmartDayPlannerApp` دیگر این dependencyها را از constructor نمی‌گیرد و فقط root برنامه را نمایش می‌دهد:

```dart
home: const SmartDayPlannerRoot()
```

## ۳. ProviderScope همچنان در main.dart مقداردهی می‌شود

در `main.dart` repositoryها همچنان ساخته و load می‌شوند، اما به جای پاس دادن مستقیم به `SmartDayPlannerApp`، با `buildAppOverrides` وارد Riverpod می‌شوند.

```dart
ProviderScope(
  overrides: buildAppOverrides(...),
  child: const SmartDayPlannerApp(),
)
```

## ۴. نتیجه معماری

مسیر dependencyها حالا تمیزتر شده است:

```text
main.dart
  -> ساخت و load repositoryها
  -> ProviderScope overrides
  -> SmartDayPlannerRoot
  -> خواندن dependencyها با ref.watch
  -> HomeScreen
```

این یعنی قدم مهمی برای حذف constructorهای شلوغ برداشته شد.

## ۵. چرا HomeScreen هنوز پارامتر می‌گیرد؟

برای جلوگیری از شکستن یک‌باره پروژه، `HomeScreen` هنوز dependencyها را از constructor دریافت می‌کند. اما دیگر `main.dart` مستقیماً آن‌ها را پاس نمی‌دهد؛ `SmartDayPlannerRoot` این کار را انجام می‌دهد.

در فازهای بعدی می‌توان خود `HomeScreen` را هم از پارامترهای repository خالی کرد و داخلش از providerها استفاده کرد.

## فایل‌های جدید فاز ۲۴

```text
lib/app/smart_day_planner_root.dart
docs/PHASE_24_REPOSITORY_INJECTION.md
```

## فایل‌های تغییرکرده

```text
lib/main.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۲۵:

- حذف repositoryها از constructor `HomeScreen`
- خواندن repositoryها مستقیم با `ref.watch` در `HomeScreen`
- تبدیل HomeScreen به coordinator با dependency کمتر
- آماده‌سازی برای widget test ساده HomeScreen با ProviderScope overrides
