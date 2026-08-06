# فاز ۲۲ اضافه شد — اتصال عملی Riverpod به HomeScreen

فاز ۲۲ ادامه مسیر معماری تمیزتر است. در فازهای قبلی Riverpod اضافه شده بود، اما در این فاز `HomeScreen` واقعاً به `ConsumerStatefulWidget` تبدیل شد و از Providerها استفاده می‌کند.

## ۱. تبدیل HomeScreen به ConsumerStatefulWidget

فایل تغییرکرده:

```text
lib/screens/home_screen.dart
```

تغییر اصلی:

```dart
class HomeScreen extends ConsumerStatefulWidget
class _HomeScreenState extends ConsumerState<HomeScreen>
```

این کار باعث می‌شود داخل صفحه بتوانیم از `ref.read` و `ref.watch` استفاده کنیم.

## ۲. استفاده از Providerها برای Controllerها

به جای ساخت مستقیم بسیاری از controllerها داخل `HomeScreen`، حالا از Providerهای تعریف‌شده در این فایل استفاده می‌شود:

```text
lib/app/app_providers.dart
```

نمونه‌ها:

```dart
_taskActions = ref.read(taskActionsControllerProvider);
_financeActions = ref.read(financeActionsControllerProvider);
_backupActions = ref.read(backupActionsControllerProvider);
_reportActions = ref.read(reportActionsControllerProvider);
```

## ۳. استفاده از ref.watch در UI

در تب داشبورد، controllerها از Provider خوانده می‌شوند:

```dart
dashboardController: ref.watch(dashboardControllerProvider)
timeAwarePlanner: ref.watch(timeAwarePlannerProvider)
```

این قدم اول برای reactive کردن کامل UI است.

## ۴. Provider جدید برای TimeAwarePlanner

فایل تغییرکرده:

```text
lib/app/app_providers.dart
```

Provider جدید:

```dart
final timeAwarePlannerProvider = Provider<TimeAwarePlanner>((ref) => const TimeAwarePlanner());
```

## ۵. نتیجه فاز ۲۲

تا قبل از این فاز، Providerها بیشتر آماده‌سازی بودند. الان استفاده عملی شروع شد:

- HomeScreen به Riverpod وصل شد
- Controllerها از ref خوانده می‌شوند
- DashboardTab از provider استفاده می‌کند
- مسیر حذف ساخت مستقیم controllerها آماده شد

## قدم بعدی پیشنهادی

فاز ۲۳:

- تعریف Provider برای repositoryهای اصلی
- حذف پاس دادن repositoryها از constructor صفحه‌ها
- تبدیل تب‌ها به ConsumerWidget
- استفاده از StateNotifier/Notifier برای stateهای پیچیده
- تست widgetها با ProviderScope و override کردن providerها
