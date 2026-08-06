# معماری پیشنهادی پروژه بعد از فاز ۱۳

پروژه تا فاز ۱۲ قابلیت‌های زیادی گرفت و فایل `home_screen.dart` بزرگ شد. فاز ۱۳ شروع refactor است تا پروژه قابل نگهداری‌تر شود.

## لایه‌ها

```text
lib/
  app/
    app_providers.dart
  application/
    dashboard/
    finance/
    assistant/
    settings/
  domain/
    usecases/
  models/
  services/
  screens/
  widgets/
  utils/
```

## توضیح لایه‌ها

### app
وابستگی‌ها و provider های سطح برنامه.

### application
Controller و State های مخصوص صفحه‌ها. این لایه باید داده خام را از سرویس‌ها بگیرد و برای UI آماده کند.

### domain
منطق خالص و قابل تست. مثل محاسبه درآمد روزانه لازم برای هدف مالی.

### services
سرویس‌های زیرساختی و business فعلی، مثل:

- FinanceRepository
- DebtPlanningService
- VoiceCommandProcessor
- BackupService
- CalendarService

### screens/widgets
فقط UI. هدف refactor این است که محاسبات از این لایه خارج شود.

## Riverpod

در فاز ۱۳ پکیج `flutter_riverpod` اضافه شد و `ProviderScope` در `main.dart` قرار گرفت.

فایل provider ها:

```text
lib/app/app_providers.dart
```

## قدم‌های بعدی refactor

1. انتقال منطق داشبورد از `home_screen.dart` به `DashboardController`
2. انتقال منطق حسابدار به `FinanceController`
3. تبدیل `HomeScreen` به `ConsumerWidget` یا `ConsumerStatefulWidget`
4. نوشتن تست برای usecase ها
5. کوچک کردن ویجت‌های بزرگ به فایل‌های جدا

## قانون پیشنهادی

- UI نباید محاسبات مالی انجام دهد.
- UI نباید مستقیماً با چندین repository کار کند.
- منطق قابل تست باید در domain/application باشد.
- سرویس‌ها باید تا حد ممکن مستقل از Flutter UI باشند.
