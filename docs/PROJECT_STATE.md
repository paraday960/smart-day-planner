# 📌 وضعیت پروژه — راهنمای ورود سریع (برای انسان و هوش مصنوعی)

> این سند «نقطهٔ ورود» پروژه است. هر کسی (یا هر AI) که به این ریپو وصل میشود
> اول این فایل را بخواند تا بداند کار تا کجا پیش رفته، چه چیزهایی درست شده و
> چه چیزهایی هنوز مانده است. آخرین بهروزرسانی: **2026-08-07** (آخرین کامیت: `6bd1bee`).

---

## ۱. خلاصهٔ وضعیت (وضعیت: 🟢 سبز)

| مورد | وضعیت |
|---|---|
| **CI (Flutter CI روی `main`)** | ✅ **سبز** — همهٔ ۱۶ استپ موفق |
| **تستهای واحد** | ✅ ۱۳۰ تست پاس، ۵ اسکیپ (نیازمند دستگاه واقعی) |
| **تستهای feature gating** | ✅ ۵ تست پاس (با dart-define های امن) |
| **بیلد APK دیباگ** | ✅ موفق + آپلود بهعنوان artifact |
| **تاریخچهٔ گیت** | تمیز — ۵۶ کامیت، بدون کامیت تشخیصی موقت |
| **آخرین کامیت** | `6bd1bee` — مستندات (CI سبز) |

### ⚠️ قبل از هر تغییری حتماً این را بدانید
- **Workflow ها را تغییر ندهید** مگر اینکه حتماً لازم باشد؛ CI روی هر `push` به `main`
  اجرا میشود و شامل: تست واحد، تست gating، و بیلد APK دیباگ است.
- **CI را با یک push خالی تست نکنید** — کامیت واقعی بزنید.
- **`flutter test` را قبل از push حتماً اجرا کنید** (اگر Flutter محلی دارید)؛
  تستها سریع هستند (~۳ دقیقه روی CI).

---

## ۲. تاریخچهٔ اخیر — چه اتفاقی افتاده (اوت ۲۰۲۶)

### ۶ آگوست
- `f0ee591` (**PR #1**): ارتقای امنیت بکاپ — **AES-GCM + PBKDF2** (۲۰۰٬۰۰۰ تکرار)،
  قالب بکاپ v2، حذف کد مرده، `docs/KNOWN_GAPS.md` و گزارش `بررسی-کد-REVIEW.md`.
- **قطعی سراسری GitHub Actions** (۱۵:۲۲ UTC به بعد) → رانهای CI چند ساعته در صف
  ماندند و کامیتهای بعدی (که شامل باگهای کامپایل بودند) **هرگز CI نگرفتند**.

### ۷ آگوست — تعمیر کامل CI (`dc4fed6`)
بعد از رفع قطعی، CI اجرا شد و **۱۳ باگ** پیدا و رفع شد (از ۷۵/۱۷ به ۱۳۰/۰):

**کد اصلی (باگهای واقعی):**
1. **کوراپشن `\${` بهجای `${`** در `lib/services/local_assistant.dart` (۳۸ مورد)
   و `lib/presentation/dashboard/dashboard_tab.dart` (۱ مورد) — کد هرگز کامپایل نمیشد.
   (احتمالاً هنگام تولید کد با heredoc در سندباکس رخ داده است؛ هنگام نوشتن فایل
   Dart با python/bash حواستان به escape کردن `$` باشد!)
2. **خطای سینتکس `DashboardController`**: سمیکالن اضافی بعد از `_habitInsight = habitInsight;`
   که `_aiBrain = aiBrain;` را از initializer list جدا میکرد.
3. **باگ منطقی در `voice_command_processor`**: «میلیون» حاوی «و» است و تابع
   `_extractMultiDebtPersons` روی «و» اسپلیت میکرد → «به ممد یک میلیون بدهکارم»
   اشتباهاً مسیر چندبدهی را فعال میکرد. حالا فقط روی `\s+و\s+` اسپلیت میشود و
   کلمات شامل «میلیون/هزار/تومان» فیلتر میشوند.
4. **`WorkLearningService`**: تراکنشهای درآمدی دوباره به `totalMinutes` اضافه میشدند
   (کارِ همان تراکنش دوبار شمرده میشد) → حالا تراکنشها فقط برای شمارش «روزهای کاری»
   و محاسبهٔ نرخ ساعتی استفاده میشوند. `hasEnoughData` هم به
   `sampleCount >= 3 && (avgDailyWorkMinutes > 0 || avgHourlyRate > 0)` تغییر کرد.
5. **Import ها و API های گمشده/اشتباه**: `DebtRepository` در `local_assistant.dart`،
   `VoiceResponsePort` در `assistant_coordinator.dart`، `budgets.budgets` →
   `budgets.items`، `b.limit` → `b.monthlyLimit`،
   `vosk.initSpeechService(recognizer:)` → `vosk.initSpeechService(_recognizer!)`.
6. **تستپذیری کاراکتر دستیار**: `Future.delayed` های بیپایان → `Timer` قابل لغو
   (`animated_assistant_character.dart`) + گارد پلتفرم برای `ModelViewer`
   (فقط اندروید/iOS — `assistant_3d_viewer.dart`).

**تستها:**
7. `TaskStatus.open` → `TaskStatus.todo` (enum فقط `todo`/`done` دارد!)
8. حذف پارامتر ناموجود `hourlyRate:` از سازندهٔ `FinanceTransaction` در ۲ تست.
9. بهروزرسانی متنهای EmptyState و اسکرول در تستهای ویجت.

**بیلد اندروید (زنجیرهٔ ۶ خطا):**
10. `android/app/build.gradle.kts`: import های صریح `Properties`/`FileInputStream` +
    `isCoreLibraryDesugaringEnabled = true`.
11. `android/build.gradle.kts`: تزریق `namespace` و `compileSdk = 36` به پکیجهای
    قدیمی (مثل `vosk_flutter 0.3.48`) با گارد `state.executed` برای `afterEvaluate`
    (بدون گارد، خطای «already evaluated» میگیرید؛ `newDsl=true` هم پلاگین Flutter
    را میشکند — **نزنید!**).
12. `pubspec.yaml`: ارتقای `permission_handler` به 13 و `permission_handler_android`
    به 13 (نسخهٔ 14 به compileSdk 37 نیاز دارد که AGP 9.0.1 پشتیبانی نمیکند).
    ⚠️ در این مسیر ساختار pubspec.yaml یکبار خراب شد (`sqflite_common_ffi` داخل
    `dependency_overrides` افتاد) — `sqflite_common_ffi` باید زیر `dev_dependencies` باشد.
13. `android/gradle.properties`: حافظهٔ Gradle از 768m به **3g** افزایش یافت
    (768m برای AGP 9 + Kotlin باعث GC thrashing میشد).

---

## ۳. معماری سریع

```
lib/
├── app/                  # providers (Riverpod)، feature_flags، root widget
├── application/          # controllers/coordinators (لایهٔ منطق)
├── domain/               # Port ها (interfaces) — services/ پیادهسازی میکند
├── models/               # Task, FinanceTransaction, DebtItem, ...
├── presentation/         # tabs: dashboard, tasks, finance, assistant, settings, onboarding
├── screens/              # home_screen (TabBar اصلی)
├── services/             # پیادهسازیها: smart_planner, local_assistant (AI قانونمحور),
│                         #   ai_brain, backup_service (AES-GCM), voice, llama, vosk, sqflite repos
└── utils/                # persian_format (اعداد/مبلغ فارسی)
test/                     # ۳۳ فایل تست — همهٔ تستها روی CI اجرا میشوند
android/                  # AGP 9.0.1، Kotlin DSL، compileSdk 36، minSdk flutter
```

نکتهها:
- معماری **Port/Adapter** است: `domain/services/*_port.dart` قراردادها،
  `services/*.dart` پیادهسازیها.
- دستیار هوشمند **بدون API پولی** کار میکند: `RuleBasedLocalAssistant` (NLU فارسی
  قانونمحور) بهعلاوهٔ LLM محلی اختیاری (llama.cpp — غیرفعال پیشفرض).
- ذخیرهسازی: `sqflite` + `shared_preferences`.
- زبان رابط: فارسی، تاریخ شمسی، پول تومان.

---

## ۴. اجرا و تست

```bash
flutter pub get
flutter test --exclude-tags=needs-real-device        # تستهای واحد (۱۳۰ تست)
flutter test test/feature_gating_widget_test.dart \
  --dart-define=ENABLE_VOICE_INPUT=false \
  --dart-define=ENABLE_VOICE_RESPONSE=false \
  --dart-define=ENABLE_CALENDAR=false \
  --dart-define=ENABLE_PDF_EXPORT=false \
  --dart-define=ENABLE_SHARE_FILES=false \
  --dart-define=ENABLE_SMART_NOTIFICATIONS=false \
  --dart-define=ENABLE_ENCRYPTED_BACKUP=false        # تست gating (۵ تست)
flutter build apk --debug                            # بیلد APK دیباگ
```

CI دقیقاً همین دستورها را اجرا میکند (`.github/workflows/flutter_ci.yml`).
راهنمای بیلد Release: `docs/BUILD_RELEASE_GUIDE.md`.

---

## ۵. دانلود APK (آخرین نسخهٔ نصبشدنی)

هر push به `main` یک APK دیباگ میسازد و آپلود میکند:

1. به **Actions** ریپو بروید: `https://github.com/paraday960/smart-day-planner/actions`
2. روی آخرین ران سبز (Flutter CI) کلیک کنید.
3. به پایین بروید → بخش **Artifacts** → روی **`smart-day-planner-debug-apk`** کلیک کنید.
4. داخل فایل zip، فایل `app-debug.apk` است — قابل نصب روی اندروید (نسخهٔ ۶+).

> APK دیباگ با کلید debug امضا شده و برای تست/نصب مستقیم مناسب است.
> برای انتشار واقعی، workflow `release_android.yml` را با `Run workflow` اجرا کنید
> (نیاز به دسترسی Actions:write دارد) یا از `docs/BUILD_RELEASE_GUIDE.md` پیروی کنید.

---

## ۶. شکافها و کارهای بعدی (مهم!)

جزئیات کامل: **`docs/KNOWN_GAPS.md`**. خلاصه:

1. 🔴 **LLM محلی (llama.cpp)**: زیرساخت کامل است ولی `libllama.so` و مدل GGUF
   باندل نشدهاند؛ فلگ `ENABLE_LOCAL_LLM` خاموش است.
2. 🔴 **تشخیص گفتار آفلاین (Vosk)**: کد آماده است ولی مدل فارسی باندل نشده؛
   `ENABLE_OFFLINE_SPEECH` خاموش است.
3. 🔴 **iOS**: پوشهٔ `ios/` در ریپو وجود ندارد (فقط اندروید).
4. 🟡 **تستهای widget گیتشده**: ۵ تست `feature_gating` فقط با
   `--dart-define=ENABLE_VOICE_INPUT=false` اجرا میشوند (پیشفرض true → skip).
5. 🟡 **پکیجهای قدیمی**: `vosk_flutter 0.3.48` و چند پکیج دیگر API های قدیمی
   دارند؛ با ارتقای Flutter/AGP ممکن است نیاز به تزریق namespace/compileSdk
   دوباره پیدا شود (همین الان در `android/build.gradle.kts` انجام شده).
6. 🟡 **Node 20 deprecation** در CI: `actions/checkout@v4` و `setup-java@v4`
   هشدار میدهند — ارتقا به v5 در فرصت مناسب.
7. 🟡 **بکاپهای v1**: دیگر قابل بازیابی نیستند (عمدی — قالب v2).

---

## ۷. دستورالعمل برای هوش مصنوعی / همکار بعدی

1. **اول این فایل و `docs/KNOWN_GAPS.md` را بخوانید.**
2. وضعیت CI را چک کنید: `gh run list` یا صفحهٔ Actions.
3. قبل از تغییر، مطمئن شوید `flutter test` محلی یا CI سبز است.
4. اگر خطای کامپایل میبینید، اول این الگوها را چک کنید (باگهای قبلی):
   - `\${` در فایلهای Dart (کوراپشن escape)
   - `TaskStatus.open` (وجود ندارد — فقط `todo`/`done`)
   - پارامترهای ناموجود در سازندهٔ مدلها (مثل `hourlyRate:` در FinanceTransaction)
   - کامیتهایی که «هرگز CI نگرفتند» ممکن است باگ کامپایل داشته باشند
5. **قبل از push حتماً `git diff` را بررسی کنید** که فایلهای تست/تشخیصی موقت
   (ok_test، disabled_tests، diag_*) در درخت نمانده باشند.
6. لاگهای CI را میتوانید از URL های `productionresultssa*.blob.core.windows.net`
   (redirect از API) بخوانید — فقط چند دقیقه اعتبار دارند.
7. اگر توکن GitHub App است: **Workflow و dispatch را نمیتواند تغییر دهد**
   (فقط `actions: read`) — CI را با push به main اجرا کنید، نه با dispatch.
