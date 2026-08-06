# فاز ۱۴ اضافه شد — شکستن UI و اتصال اولیه Controller ها به صفحه امروز

فاز ۱۴ ادامه فاز ۱۳ است و هدف آن کوچک کردن `home_screen.dart` و شروع مهاجرت واقعی UI به ساختار جدید است.

## ۱. استخراج ویجت‌های مشترک

پوشه جدید:

```text
lib/presentation/shared/
```

فایل‌های جدید:

```text
metric_card.dart
goal_progress_card.dart
plan_card.dart
```

این ویجت‌ها قبلاً داخل `home_screen.dart` بودند یا منطق مشابه داشتند. حالا قابل استفاده در چند صفحه هستند.

## ۲. استخراج صفحه داشبورد امروز

پوشه جدید:

```text
lib/presentation/dashboard/
```

فایل جدید:

```text
dashboard_tab.dart
```

تب «امروز» از داخل `home_screen.dart` جدا شد و به `DashboardTab` منتقل شد.

## ۳. اتصال DashboardController به UI

در فاز ۱۳ `DashboardController` ساخته شده بود. در فاز ۱۴، `DashboardTab` از آن برای ساخت `DashboardState` استفاده می‌کند.

یعنی محاسباتی مثل این‌ها دیگر مستقیماً در UI اصلی نیستند:

- تعداد کارهای باز
- تعداد کارهای انجام‌شده امروز
- پیشنهادهای هوشمند
- تحلیل هفته
- تحلیل عادت‌ها
- برنامه پیشنهادی امروز
- پیام‌های بدهی و هزینه آینده

## ۴. کاهش مسئولیت HomeScreen

`HomeScreen` هنوز کامل refactor نشده، اما یک قدم مهم انجام شد:

- تب امروز از فایل اصلی خارج شد.
- ویجت‌های مشترک از فایل اصلی خارج شدند.
- مسیر مهاجرت برای تب‌های بعدی آماده شد.

## ۵. ساختار جدید presentation

```text
lib/presentation/
  dashboard/
    dashboard_tab.dart
  shared/
    metric_card.dart
    goal_progress_card.dart
    plan_card.dart
  finance/
  assistant/
  settings/
```

پوشه‌های `finance`، `assistant` و `settings` برای فازهای بعدی آماده شده‌اند.

## فایل‌های جدید فاز ۱۴

```text
lib/presentation/dashboard/dashboard_tab.dart
lib/presentation/shared/metric_card.dart
lib/presentation/shared/goal_progress_card.dart
lib/presentation/shared/plan_card.dart
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
README.md
docs/PHASE_14_REFACTOR_UI.md
```

## قدم بعدی پیشنهادی

فاز ۱۵ باید ادامه همین مسیر باشد:

- استخراج `FinanceTab` از `home_screen.dart`
- استخراج `AssistantTab`
- استخراج `SettingsTab`
- تبدیل تب‌ها به `ConsumerWidget`
- استفاده بیشتر از Provider ها
- حذف کامل محاسبات از UI
