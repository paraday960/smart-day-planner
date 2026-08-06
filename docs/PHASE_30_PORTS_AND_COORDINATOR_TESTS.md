# فاز ۳۰ اضافه شد — Repository Ports و تست HomeCoordinator

فاز ۳۰ یک گام معماری مهم است: به جای اینکه منطق هماهنگ‌کننده فقط به کلاس‌های concrete مثل SQLite Repository وابسته باشد، یک لایه Contract/Port اضافه شد تا بتوان منطق را با fake repository تست کرد.

## ۱. Repository Portها

پوشه جدید:

```text
lib/domain/repositories/
```

فایل‌های جدید:

```text
task_repository_port.dart
finance_repository_port.dart
debt_repository_port.dart
allocation_repository_port.dart
```

این فایل‌ها قراردادهای ساده برای repositoryها تعریف می‌کنند.

## ۲. HomeCoordinatorV2

فایل جدید:

```text
lib/application/home/home_coordinator_v2.dart
```

این نسخه از coordinator به interfaceها وابسته است، نه implementationهای واقعی. بنابراین می‌توان آن را بدون دیتابیس، بدون SharedPreferences و بدون Flutter platform تست کرد.

قابلیت‌های فعلی:

- ذخیره کار
- کامل کردن کار
- پرداخت بدهی/دریافت طلب و ساخت تراکنش مالی
- کنار گذاشتن پول در پاکت‌ها

## ۳. تست HomeCoordinatorV2

فایل جدید:

```text
test/home_coordinator_v2_test.dart
```

این تست‌ها با fake repositoryها بررسی می‌کنند:

- پرداخت بدهی باعث افزایش مبلغ پرداخت‌شده و ثبت تراکنش هزینه می‌شود.
- کنار گذاشتن پول باعث ثبت allocation می‌شود.

## ۴. چرا V2 جدا ساخته شد؟

برای اینکه پروژه فعلی نشکند. Repositoryهای فعلی هنوز concrete هستند و در UI استفاده می‌شوند. نسخه V2 مسیر مهاجرت امن را نشان می‌دهد:

```text
UI → CoordinatorV2 → Repository Ports → Implementations
```

در فازهای بعدی می‌توان repositoryهای فعلی را به این Portها وصل کرد.

## فایل‌های جدید فاز ۳۰

```text
lib/domain/repositories/task_repository_port.dart
lib/domain/repositories/finance_repository_port.dart
lib/domain/repositories/debt_repository_port.dart
lib/domain/repositories/allocation_repository_port.dart
lib/application/home/home_coordinator_v2.dart
test/home_coordinator_v2_test.dart
docs/PHASE_30_PORTS_AND_COORDINATOR_TESTS.md
```

## قدم بعدی پیشنهادی

فاز ۳۱:

- implement کردن Portها در repositoryهای واقعی
- مهاجرت HomeCoordinator اصلی به Portها
- حذف تدریجی وابستگی به کلاس‌های concrete
- افزایش تست‌های usecase و coordinator
- آماده‌سازی معماری Clean Architecture واقعی
