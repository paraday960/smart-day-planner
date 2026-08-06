# بررسی فنی پروژه «دستیار روزانه هوشمند ایرانی»

**ریپازیتوری:** `paraday960/smart-day-planner`
**برنچ:** `main` (آخرین کامیت: `30c31b0` — «AppTheme واحد حرفهای»)
**تکنولوژی:** Flutter / Dart (Android + iOS)، فارسی و راستچین، شمسی، تومان

> ⚠️ **محدودیت بررسی:** در این سندباکس Flutter نصب نیست و دانلود آن از
> Google Storage مسدود بود؛ بنابراین `flutter analyze` و `flutter test` قابل اجرا
> نبودند. این بررسی **استاتیک** (خواندن کامل کد) است، نه اجرای واقعی. نتایج
> «build/analyze» و تستها روی CI گیتهاب (workflow موجود) باید اجرا شوند.

---

## ۱) خلاصه — این پروژه چیست؟

یک اپ Flutter آفلاین و «بدون API پولی» برای برنامهریزی روزانه، حسابداری شخصی،
مدیریت بدهی/طلب، هدفگذاری مالی و دستیار صوتی فارسی. هستهٔ هوشمندی Rule-Based است
و جایگاه اتصال LLM محلی (llama.cpp) هم آماده شده (Feature Flag، پیشفرض خاموش).

## ۲) آمار کلی

| مورد | مقدار |
|---|---|
| فایلهای Dart در `lib/` | 119 |
| کل خطوط کد `lib/` | ~۱۵٬۰۷۳ |
| فایلهای تست `test/` | 36 |
| Dependencyهای اصلی | Riverpod, sqflite, speech_to_text, flutter_tts, encrypt, pdf, share_plus, device_calendar, shamsi_date, model_viewer_plus, vosk_flutter |
| CI | ۲ workflow گیتهاب (flutter_ci + release_android) |

## ۳) نقاط قوت ✅

1. **معماری رو به بهبود و جدی:** لایهبندی `app / application / domain / models /
   presentation / services` وجود دارد و سیر refactor در ۳۹ فاز مستند شده است.
   Repository Portها (اینترفیسهای domain) جدا از پیادهسازیهای واقعی هستند
   (`lib/domain/repositories/*_port.dart`) که تستپذیری را واقعاً بالا میبرد.
2. **تست خوب و متنوع:** ۳۶ فایل تست شامل Widget Test، تست ActionController با
   fake repository/پلتفرم، تست سناریوی end-to-end، تست خطای بازیابی بکاپ و تست
   قابلاعتماد (confidence) فرمانهای مالی.
3. **پوشش و CI:** اجرای `flutter test --coverage` با حداقل ۳۰٪ coverage در CI و
   آپلود `lcov.info` به عنوان artifact — خوب است که حداقل آستانه را گذاشتند.
4. **Feature Flags خوب:** `ENABLE_*` با `bool.fromEnvironment` برای خاموشکردن
   قابلیتهای پرریسک در build پایدار (voice, calendar, pdf, share, notifications…).
5. **مستندات فارسی و کامل:** ۳۹+ فایل فاز و راهنمای معماری، CI/CD، ریسکهای build،
   حریم خصوصی، دستورات صوتی، سیاست «بدون هزینه پولی».
6. **سینگلتونهای سرویسهای پلتفرمی** (Notification/Calendar/Share/Voice) از طریق
   Port جدا شدهاند که در تست با fake جایگزین میشوند.
7. تم واحد (`AppTheme`)، فونت فارسی Vazirmatn، اعداد/تاریخ شمسی و تومان یکپارچه.
8. `home_screen.dart` از فایلهای غولپیکر به ~۸۲۳ خط و به coordinator لایهبندی
   شده؛ مسئولیتها به ActionController و Dialogهای جداگانه منتقل شده.

## ۴) یافتهها و مشکلات 🔍

### ۴.۱ — امنیت رمزنگاری (اولویت بالا)

**الف) هش PIN با SHA-256 بدون KDF** — `lib/services/security_service.dart`:

```dart
String _hashPin(String pin, String salt) {
  return sha256.convert(utf8.encode('$salt|$pin|smart_day_planner')).toString();
}
```

PIN ۴رقمی + SHA-256 خام (سریع) → حملات brute-force روی ۱۰٬۰۰۰ ترکیب بسیار آسان است.
بهتر است PBKDF2 یا Argon2id با salt و iterationهای زیاد (مثلاً ۱۰۰k+) استفاده شود.

**ب) استخراج کلید بکاپ بدون salt و بدون KDF** — `lib/services/backup_service.dart`:

```dart
enc.Key _keyFromPassphrase(String passphrase) {
  final digest = sha256.convert(utf8.encode('smart_day_planner|${passphrase.trim()}')).bytes);
  return enc.Key(Uint8List.fromList(digest));
}
```

پسورد ضعیف + SHA-256 خام بدون salt → brute-force/دیکشنری ساده. توصیه: PBKDF2/Argon2.

**ج) AES-CBC بدون احراز اصالت (no MAC / GCM)** — همان `backup_service.dart`:

```dart
enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
```

CBC بدون MAC قابلمانیپولیشن است (attacker میتواند بایتها را تغییر دهد). توصیه:
استفاده از **AES-GCM** (مثل `package:cryptography`) که هم محرمانگی و هم احراز اصالت
دارد و در حین restore، دستکاری/خطای رمز بهدرستی خطا میدهد.

### ۴.۲ — کد مرده / refactor ناتمام (اولویت متوسط)

- `HomeCoordinatorV2` و `HomeCoordinatorFactory` (فاز ۳۰–۳۱) تعریف شده و Provider
  `homeCoordinatorV2Provider` وجود دارد، **ولی UI هنوز از `HomeCoordinator` قدیمی
  (`homeCoordinatorProvider`) استفاده میکند**. این یعنی دو پیادهسازی همزمان همارز
  در کد وجود دارد که یکی استفاده نمیشود → خطر divergence و گیجی نگهداری. یا باید
  V2 بهعنوان تنها مسیر فعال شود یا کد قدیمی حذف شود.
- در `home_screen.dart` هم `AssistantCoordinator` و `TaskFlowCoordinator` جدید با
  کامنت «Refactor 2026-08-06» اضافه شدهاند — یعنی هنوز میانهٔ refactor هستیم و
  پایداری آن باید با تست محکم شود.

### ۴.۳ — استارتآپ روی همان isolate (اولویت متوسط)

در `main.dart` همهٔ ۱۰+ `.load()` بهصورت **سریال** و `await` قبل از `runApp` اجرا
میشوند (TaskRepository, FinanceRepository, GoalRepository, … + SecurityService +
NotificationService + VoiceResponseService). این روی isolate اصلی و بدون صفحهٔ
بارگذاری انجام میشود → میتواند استارت را کند کند. بهتر است: loadها به موازات
(`Future.wait`) و/یا به `Isolate.run` یا صفحهٔ Splash منتقل شوند.

### ۴.۴ — فایلهای بزرگ (اولویت کم)

- `lib/services/local_assistant.dart` → ۱٬۱۲۵ خط
- `lib/services/voice_command_processor.dart` → ۱٬۰۷۵ خط
- `lib/presentation/finance/finance_tab.dart` → ۵۴۴ خط

در حالی که بقیهٔ پروژه به خوبی شکسته شده، این فایلها هنوز بزرگ هستند و ارزش
جداسازی دارند (همان الگویی که برای home_screen انجام شد).

### ۴.۵ — نکات جزئی

- رشتههای پیام رابط کاربری مستقیماً در کد فارسی نوشته شدهاند (بدون
  AppLocalizations/intl l10n). برای یک اپ فارسی تکزبانه فعلاً قابل قبول است، اما
  تستپیچیدگی و امکان چندزبانهشدن را سخت میکند.
- `FeatureFlags.hasRiskyPlatformFeatureEnabled` فقط OR میکند و در کد جایی استفاده
  نشده (کد مردهٔ بالقوه).

## ۵) پیشنهادهای اولویتدار 🎯

1. **امنیت (بالاترین اولویت):** جایگزینی SHA-256 خام با PBKDF2/Argon2 برای PIN و
   کلید بکاپ، و مهاجرت بکاپ به **AES-GCM** با salt. اینها مربوط به دادهٔ مالی
   کاربر است و ارزش جدی دارد.
2. **پاکسازی refactor:** تصمیم قطعی بین `HomeCoordinator` (قدیمی) و V2؛ حذف مسیر
   مرده یا فعالسازی کامل آن + تست.
3. **استارت سریعتر:** موازیسازی/ایزولهکردن load ها با صفحهٔ Splash.
4. **جداسازی فایلهای بزرگ** `local_assistant` و `voice_command_processor`.
5. **اجرای CI/تست واقعی:** قبل از انتشار، `flutter analyze` و `flutter test
   --coverage` را روی یک محیط با Flutter واقعی (یا CI گیتهاب) اجرا کنید؛ چون در
   این محیط امکان اجرا نبود.

## ۶) جمعبندی

پروژه از نظر وسعت ویژگیها، مستندسازی و نظم معماری در وضعیت خوب و رو به رشدی است و
مسیر refactor به سمت Clean Architecture جدی گرفته شده. مهمترین نگرانی، **امنیت
رمزنگاری** (PIN و بکاپ) است که قبل از انتشار عمومی باید اصلاح شود؛ سپس تکمیل/
پاکسازی refactor همارزهای دوگانه و بهبود استارتآپ.
