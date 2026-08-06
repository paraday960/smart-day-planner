# فاز ۲۸ اضافه شد — ConsumerWidget تکمیلی و Widget Testهای بیشتر

فاز ۲۸ ادامه فاز ۲۷ است و روی کامل‌تر کردن استفاده از Riverpod داخل تب‌ها و افزایش پوشش تست Widget تمرکز دارد.

## ۱. SettingsTab به ConsumerWidget تبدیل شد

فایل تغییرکرده:

```text
lib/presentation/settings/settings_tab.dart
```

قبلاً `SettingsTab` سرویس امنیت را از بیرون می‌گرفت. حالا خودش از Provider می‌خواند:

```dart
final securityService = ref.watch(securityServiceProvider);
```

بنابراین وابستگی مستقیم آن کمتر شد.

## ۲. AssistantTab به ConsumerWidget تبدیل شد

فایل تغییرکرده:

```text
lib/presentation/assistant/assistant_tab.dart
```

این تغییر مسیر را برای خواندن تنظیمات صوتی و وضعیت دستیار از Providerها در فازهای بعدی آماده می‌کند.

## ۳. FinanceTab بیشتر مستقل شد

فایل تغییرکرده:

```text
lib/presentation/finance/finance_tab.dart
```

در این فاز:

- `FinanceTab` از `financeControllerProvider` استفاده می‌کند.
- `FinanceAssistant` هم از Provider خوانده می‌شود.
- dependencyهای محاسباتی بیشتری از داخل تب خوانده می‌شوند.

## ۴. Widget Test برای TasksTab

فایل جدید:

```text
test/tasks_tab_widget_test.dart
```

این تست بررسی می‌کند `TasksTab` با ProviderScope و overrideها render می‌شود و حالت خالی کارها را نشان می‌دهد.

## ۵. Widget Test برای FinanceTab

فایل جدید:

```text
test/finance_tab_widget_test.dart
```

این تست بررسی می‌کند `FinanceTab` با ProviderScope و overrideها render می‌شود و بخش‌های کلیدی حسابدار نمایش داده می‌شوند.

## ۶. وضعیت تست‌های Widget

تا الان تست‌های Widget داریم برای:

```text
DashboardTab
TasksTab
FinanceTab
```

## فایل‌های تغییرکرده/جدید فاز ۲۸

```text
lib/presentation/settings/settings_tab.dart
lib/presentation/assistant/assistant_tab.dart
lib/presentation/finance/finance_tab.dart
test/tasks_tab_widget_test.dart
test/finance_tab_widget_test.dart
docs/PHASE_28_WIDGET_TESTS_CONSUMER_REFACTOR.md
```

## قدم بعدی پیشنهادی

فاز ۲۹:

- ساخت HomeCoordinator برای حذف callbackهای زیاد از HomeScreen
- تست HomeScreen کامل با ProviderScope overrides
- ساخت fake repositoryهای سبک برای تست‌های سریع‌تر
- تکمیل حذف dependencyهای باقی‌مانده از FinanceTab
