# فاز ۳۲ اضافه شد — مهاجرت Coordinator اصلی به Portها و تکمیل Repository Contracts

فاز ۳۲ ادامه فاز ۳۱ است. در فاز ۳۱ repositoryهای اصلی به Portهای اولیه وصل شدند. در فاز ۳۲ Portهای بیشتری اضافه شد و `HomeCoordinator` اصلی به جای وابستگی مستقیم به repositoryهای concrete، به Portها وابسته شد.

## ۱. Portهای جدید

فایل‌های جدید:

```text
lib/domain/repositories/goal_repository_port.dart
lib/domain/repositories/planned_expense_repository_port.dart
lib/domain/repositories/category_budget_repository_port.dart
lib/domain/repositories/availability_repository_port.dart
```

این‌ها قراردادهای domain برای این بخش‌ها هستند:

- هدف‌ها
- هزینه‌های آینده
- بودجه دسته‌بندی‌ها
- تنظیمات زمان آزاد

## ۲. Repositoryهای واقعی Portهای جدید را پیاده‌سازی می‌کنند

فایل‌های تغییرکرده:

```text
lib/services/goal_repository.dart
lib/services/planned_expense_repository.dart
lib/services/category_budget_repository.dart
lib/services/availability_repository.dart
```

حالا این کلاس‌ها `implements ...Port` دارند.

## ۳. انتقال WorkTimeSettings به models

برای جلوگیری از وابستگی domain به service، مدل زمان کاری جدا شد:

```text
lib/models/work_time_settings.dart
```

و `AvailabilityRepository` از آن استفاده می‌کند.

## ۴. HomeCoordinator اصلی به Portها وابسته شد

فایل تغییرکرده:

```text
lib/application/home/home_coordinator.dart
```

قبلاً این coordinator به کلاس‌های concrete مثل `TaskRepository` و `FinanceRepository` وابسته بود. حالا از Portها استفاده می‌کند:

```dart
TaskRepositoryPort
FinanceRepositoryPort
GoalRepositoryPort
PlannedExpenseRepositoryPort
DebtRepositoryPort
AllocationRepositoryPort
CategoryBudgetRepositoryPort
AvailabilityRepositoryPort
```

## ۵. Action Controllerها هم به Portها نزدیک‌تر شدند

فایل‌های تغییرکرده:

```text
lib/application/tasks/task_actions_controller.dart
lib/application/finance/finance_actions_controller.dart
lib/application/actions/debt_actions_controller.dart
lib/application/actions/allocation_actions_controller.dart
lib/application/actions/goal_actions_controller.dart
lib/application/actions/backup_actions_controller.dart
```

این controllerها حالا تا حد زیادی به Portها وابسته‌اند، نه implementation واقعی.

## ۶. BackupActionsController با Portها کار می‌کند

`BackupActionsController` حالا از Portها داده خام می‌گیرد و برای ساخت بکاپ به `BackupService` می‌دهد. این باعث می‌شود بکاپ گرفتن به concrete repository وابسته نباشد.

## ۷. تست Portها کامل‌تر شد

فایل تغییرکرده:

```text
test/repository_ports_test.dart
```

حالا تست می‌کند repositoryهای زیر Portهای مربوطه را implement می‌کنند:

- TaskRepository
- FinanceRepository
- DebtRepository
- AllocationRepository
- GoalRepository
- PlannedExpenseRepository
- CategoryBudgetRepository
- AvailabilityRepository

## نتیجه فاز ۳۲

معماری پروژه به Clean Architecture نزدیک‌تر شد:

```text
UI → Application → Repository Ports → Concrete Repositories
```

حالا application layer کمتر به دیتابیس و جزئیات ذخیره‌سازی وابسته است.

## قدم بعدی پیشنهادی

فاز ۳۳:

- تعریف Port برای سرویس‌های platform مثل Notification، Calendar و Share
- تست کامل HomeCoordinator اصلی با fake portها
- حذف کامل HomeCoordinatorV2 یا ادغام آن با HomeCoordinator اصلی
- ساخت تست‌های usecase بیشتر برای بدهی، پاکت پول و بودجه
