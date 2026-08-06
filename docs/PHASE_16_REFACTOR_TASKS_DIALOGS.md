# فاز ۱۶ اضافه شد — استخراج تب کارها و شروع جداسازی Dialogها

فاز ۱۶ ادامه مسیر refactor است. بعد از جدا شدن تب‌های امروز، حسابدار، دستیار و تنظیمات، حالا تب «کارها» هم از `home_screen.dart` خارج شد.

## ۱. استخراج تب کارها

فایل جدید:

```text
lib/presentation/tasks/tasks_tab.dart
```

کلاس‌های جدید:

```dart
TasksTab
TaskCard
```

این تب شامل:

- کارهای باز
- کارهای انجام‌شده
- امتیاز اولویت
- توضیح دلیل اولویت
- ویرایش
- کامل کردن
- بازگردانی
- سنجاق کردن
- حذف

## ۲. سبک‌تر شدن HomeScreen

قبل از فاز ۱۶، `home_screen.dart` هنوز تب کارها و کارت کار را داخل خودش داشت. حالا این‌ها جدا شدند.

اکنون `home_screen.dart` بیشتر نقش coordinator دارد:

- نگهداری repositoryها
- باز کردن فرم‌ها و dialogها
- مدیریت callbackها
- اتصال تب‌های مستقل

## ۳. شروع جداسازی Dialogها

پوشه جدید:

```text
lib/presentation/dialogs/
```

فایل جدید:

```text
common_dialogs.dart
```

این فایل helperهای مشترک برای dialogها دارد:

- confirm
- askSecretText
- showLargeText

در فازهای بعدی می‌توان dialogهای بزرگ موجود در `home_screen.dart` را به این helperها و فایل‌های مستقل منتقل کرد.

## ۴. وضعیت جدید presentation

```text
lib/presentation/
  dashboard/
    dashboard_tab.dart
  finance/
    finance_tab.dart
  assistant/
    assistant_tab.dart
  settings/
    settings_tab.dart
  tasks/
    tasks_tab.dart
  shared/
    metric_card.dart
    goal_progress_card.dart
    plan_card.dart
  dialogs/
    common_dialogs.dart
```

## فایل‌های جدید فاز ۱۶

```text
lib/presentation/tasks/tasks_tab.dart
lib/presentation/dialogs/common_dialogs.dart
docs/PHASE_16_REFACTOR_TASKS_DIALOGS.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۱۷:

- استخراج dialogهای بزرگ از `home_screen.dart`
- ساخت `TaskActionsController`
- ساخت `FinanceActionsController`
- تبدیل `HomeScreen` به coordinator خیلی سبک
- تست handlerهای عملیات مالی با mock repository
