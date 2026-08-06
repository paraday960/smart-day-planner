# فاز ۱۵ اضافه شد — استخراج تب‌های حسابدار، دستیار و تنظیمات

فاز ۱۵ ادامه فاز ۱۴ است و هدف آن کوچک‌تر کردن `home_screen.dart` و جدا کردن تب‌های اصلی به فایل‌های مستقل است.

## ۱. استخراج تب حسابدار

فایل جدید:

```text
lib/presentation/finance/finance_tab.dart
```

کلاس جدید:

```dart
FinanceTab
```

این تب شامل بخش‌های زیر است:

- درآمد و هزینه امروز
- درآمد و خالص ماه شمسی
- هدف‌های درآمدی
- هزینه‌های آینده
- بدهی‌ها و طلب‌ها
- پاکت پول
- بودجه دسته‌بندی‌ها
- نمودار درآمد/هزینه
- نمودار سهم هزینه‌های ماه
- تراکنش‌های اخیر

## ۲. استخراج تب دستیار

فایل جدید:

```text
lib/presentation/assistant/assistant_tab.dart
```

کلاس جدید:

```dart
AssistantTab
```

همراه با ویجت‌های داخلی:

- PushToTalkCard
- VoiceResponseSettingsCard

این تب شامل:

- فرمان صوتی فارسی
- پاسخ صوتی زن/مرد
- سؤال متنی از دستیار
- نمایش پاسخ دستیار

## ۳. استخراج تب تنظیمات

فایل جدید:

```text
lib/presentation/settings/settings_tab.dart
```

کلاس جدید:

```dart
SettingsTab
```

این تب شامل:

- قفل برنامه
- بکاپ رمزنگاری‌شده
- اشتراک فایل بکاپ
- خروجی CSV
- گزارش ماه شمسی
- تنظیم زمان آزاد
- تقویم گوشی
- هشدارهای هوشمند
- PDF واقعی و اشتراک‌گذاری

## ۴. کاهش حجم home_screen.dart

قبل از فاز ۱۵، `home_screen.dart` شامل تب‌های زیادی بود. بعد از این فاز:

```text
DashboardTab → قبلاً در فاز ۱۴ جدا شد
FinanceTab → جدا شد
AssistantTab → جدا شد
SettingsTab → جدا شد
```

اکنون `home_screen.dart` بیشتر نقش هماهنگ‌کننده دارد:

- نگهداری repository ها
- باز کردن dialog ها
- هندل کردن عملیات اصلی
- پاس دادن callback ها به تب‌های مستقل

## ۵. وضعیت باقی‌مانده

هنوز داخل `home_screen.dart` این بخش‌ها باقی مانده‌اند:

- TasksTab
- TaskCard
- dialog ها و handler های عملیاتی

این‌ها در فاز بعدی می‌توانند جدا شوند.

## فایل‌های جدید فاز ۱۵

```text
lib/presentation/finance/finance_tab.dart
lib/presentation/assistant/assistant_tab.dart
lib/presentation/settings/settings_tab.dart
docs/PHASE_15_REFACTOR_TABS.md
```

## فایل‌های تغییرکرده

```text
lib/screens/home_screen.dart
README.md
```

## قدم بعدی پیشنهادی

فاز ۱۶:

- استخراج TasksTab و TaskCard
- استخراج dialog ها به سرویس/ویجت مستقل
- تبدیل HomeScreen به coordinator سبک
- اتصال Riverpod به تب‌های استخراج‌شده
- نوشتن تست برای controllerهای application
