# فاز ۳۱ اضافه شد — اتصال Repositoryهای واقعی به Portها

فاز ۳۱ ادامه فاز ۳۰ است. در فاز ۳۰ Port/Interface برای repositoryها ساخته شد و `HomeCoordinatorV2` با fake repository تست شد. در فاز ۳۱ repositoryهای واقعی به آن Portها وصل شدند.

## ۱. Repositoryهای واقعی حالا Portها را پیاده‌سازی می‌کنند

فایل‌های تغییرکرده:

```text
lib/services/task_repository.dart
lib/services/finance_repository.dart
lib/services/debt_repository.dart
lib/services/allocation_repository.dart
```

تغییرات:

```dart
class TaskRepository extends ChangeNotifier implements TaskRepositoryPort
class FinanceRepository extends ChangeNotifier implements FinanceRepositoryPort
class DebtRepository extends ChangeNotifier implements DebtRepositoryPort
class AllocationRepository extends ChangeNotifier implements AllocationRepositoryPort
```

## ۲. HomeCoordinatorFactory

فایل جدید:

```text
lib/application/home/home_coordinator_factory.dart
```

این factory یک `HomeCoordinatorV2` از روی Portها می‌سازد.

## ۳. Provider برای HomeCoordinatorV2

فایل تغییرکرده:

```text
lib/app/app_providers.dart
```

Providerهای جدید:

```dart
homeCoordinatorFactoryProvider
homeCoordinatorV2Provider
```

حالا نسخه V2 coordinator می‌تواند با repositoryهای واقعی هم ساخته شود، چون repositoryهای واقعی Portها را implement کرده‌اند.

## ۴. تست اتصال Portها

فایل جدید:

```text
test/repository_ports_test.dart
```

این تست بررسی می‌کند که repositoryهای concrete واقعاً از Portهای domain پیروی می‌کنند.

## نتیجه فاز ۳۱

مسیر Clean Architecture واقعی آماده‌تر شد:

```text
Application Layer → Repository Ports → Concrete Repositories
```

این یعنی در آینده می‌توانیم منطق application را از جزئیات دیتابیس جدا نگه داریم.

## قدم بعدی پیشنهادی

فاز ۳۲:

- مهاجرت HomeCoordinator اصلی به Portها
- حذف وابستگی مستقیم HomeCoordinator به repositoryهای concrete
- افزایش تست‌های HomeCoordinatorV2
- تعریف Port برای GoalRepository و PlannedExpenseRepository
