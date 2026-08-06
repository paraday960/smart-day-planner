# فاز ۱۳ اضافه شد — معماری تمیزتر و شروع Refactor

فاز ۱۳ برای کنترل پیچیدگی پروژه اضافه شد. تا این مرحله برنامه قابلیت‌های زیادی گرفته و لازم است ساختار پروژه حرفه‌ای‌تر شود.

## ۱. اضافه شدن Riverpod

در `pubspec.yaml` اضافه شد:

```yaml
flutter_riverpod: ^2.5.1
```

در `main.dart` برنامه با `ProviderScope` اجرا می‌شود.

## ۲. پوشه app

فایل جدید:

```text
lib/app/app_providers.dart
```

Provider های سرویس‌ها و controller های اصلی در این فایل تعریف شده‌اند.

## ۳. لایه application

پوشه‌های جدید:

```text
lib/application/dashboard/
lib/application/finance/
lib/application/assistant/
lib/application/settings/
```

فایل‌های اضافه‌شده:

```text
lib/application/dashboard/dashboard_state.dart
lib/application/dashboard/dashboard_controller.dart
lib/application/finance/finance_summary.dart
lib/application/finance/finance_controller.dart
lib/application/assistant/assistant_response.dart
```

این‌ها شروع انتقال منطق از UI به controller/state هستند.

## ۴. لایه domain

پوشه جدید:

```text
lib/domain/usecases/
```

Usecase اضافه‌شده:

```text
calculate_required_daily_income.dart
```

این منطق خالص و قابل تست است.

## ۵. تست جدید

فایل جدید:

```text
test/calculate_required_daily_income_test.dart
```

برای تست محاسبه درآمد روزانه لازم تا موعد هدف.

## ۶. مستند معماری

فایل جدید:

```text
docs/ARCHITECTURE.md
```

این فایل ساختار پیشنهادی پروژه و قوانین refactor را توضیح می‌دهد.

## نکته مهم

فاز ۱۳ یک refactor تدریجی است. برای جلوگیری از شکستن پروژه، کل `home_screen.dart` یک‌باره جابه‌جا نشد. به جای آن، لایه‌های جدید و controller های قابل تست اضافه شدند تا در فازهای بعدی UI به تدریج به آن‌ها منتقل شود.

## قدم بعدی پیشنهادی

فاز ۱۴ می‌تواند شامل این‌ها باشد:

- شکستن `home_screen.dart` به چند screen مستقل
- تبدیل صفحه‌ها به ConsumerWidget
- اتصال واقعی DashboardController به UI
- تست VoiceCommandProcessor با repository های mock
- حذف منطق محاسباتی از UI
