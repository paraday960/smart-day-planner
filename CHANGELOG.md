# Changelog

## 2026-08-07 — رفع شکاف‌های KNOWN_GAPS (به مدار برگشتن) 🚀

**Refactor (شکاف ۶):**
- `VoiceCommandProcessor` (1081 → 707 خط): ابزارهای NLU خالص به `VoiceNlu` در
  `lib/services/voice_nlu.dart` منتقل شدند (نرمال‌سازی، مبلغ، نام، مهلت، ...).
- `RuleBasedLocalAssistant` (1109 → 692 خط): لیست intent ها (۴۲۰ خط) به
  `lib/services/local_assistant_intents.dart` منتقل شد.

**تست (شکاف ۵):**
- `test/voice_command_all_repos_test.dart`: با همهٔ repositoryها هیچ پیام
  «هنوز به فرمان صوتی وصل نشده» برنمی‌گردد (پاکت پول، بدهی/پرداخت/چندبدهی،
  هزینهٔ آینده، هدف، سناریوهای پیش‌بینی) + تست قرارداد پیام دفاعی.

**وب (شکاف ۴):**
- `web/index.html` + `web/manifest.json` + `web/flutter_bootstrap.js`
  (قالب استاندارد Flutter 3.22+ با آیکن‌های موجود).

**iOS (شکاف ۳):**
- پوشهٔ کامل `ios/` (قالب استاندارد Flutter): Runner.xcodeproj با UUID های
  سازگار، AppDelegate.swift، Info.plist با دسترسی‌های میکروفون/گفتار/تقویم،
  Podfile، storyboard ها و asset catalog.

**قابلیت‌های آفلاین (شکاف‌های ۱ و ۲):**
- `VoskAssetInstaller` جدید: مدل باندل‌شده را به مسیر جستجوی `VoskModelLocator`
  نصب می‌کند (قبلاً locator اصلاً asset را چک نمی‌کرد).
- رفع باگ `LlamaAssetInstaller`: مسیر نصب با `LlamaModelLocator` هماهنگ شد
  (مدل باندل‌شده حالا واقعاً پیدا می‌شود).
- `main.dart`: نصب خودکار مدل Vosk هنگام `ENABLE_OFFLINE_SPEECH=true`.
- Workflow جدید `.github/workflows/offline_capabilities.yml`: دانلود مدل Vosk
  (~۴۰MB) و LLM اختیاری (~۴۷۰MB) روی runner، باندل در APK و آپلود artifact —
  بدون سنگین کردن ریپو.

## 2026-08-07 — تعمیر کامل CI (۱۳ رفع) 🔧

کامیت `dc4fed6` — نتیجه: ۱۳۰ تست پاس + ۵ تست gating + بیلد APK سبز.

**کد:**
- رفع کوراپشن `\${` → `${` در `local_assistant.dart` (۳۸ مورد) و `dashboard_tab.dart`.
- رفع سینتکس `DashboardController` (سمیکالن اضافی در initializer list).
- رفع باگ اسپلیت «و» در مسیر چندبدهی (کلمهٔ «میلیون» دیگر چندتکه نمی‌شود).
- رفع شمارش دوبارهٔ دقیقه‌ها در `WorkLearningService` + اصلاح `hasEnoughData`.
- افزودن import های گمشده و اصلاح API های اشتباه (۶ فایل).
- تایمرهای قابل لغو در کاراکتر دستیار + گارد پلتفرم برای نمایشگر سه‌بعدی.

**تست‌ها:**
- `TaskStatus.open` → `TaskStatus.todo`؛ حذف پارامتر ناموجود `hourlyRate:`؛
  به‌روزرسانی متن‌های EmptyState و اسکرول در تست‌های ویجت.

**بیلد اندروید:**
- import های Kotlin و desugaring در `build.gradle.kts`.
- تزریق namespace و compileSdk=36 به پکیج‌های قدیمی (vosk_flutter) با گارد `state.executed`.
- ارتقای `permission_handler` به 13 (سازگار با AGP 9 و compileSdk 36).
- اصلاح ساختار `pubspec.yaml` و افزایش حافظهٔ Gradle به 3G.

## 2026-08-06 — ارتقای امنیت بکاپ + تمیزکاری 🔒

### امنیت
- `BackupService`: مهاجرت از AES-CBC (بدون احراز اصالت) به **AES-GCM** برای رمزنگاری بکاپ — دستکاری فایل یا رمز اشتباه حالا تشخیص داده می‌شود.
- استخراج کلید بکاپ از `sha256(prefix|passphrase)` (بدون نمک) به **PBKDF2-HMAC-SHA256** با نمک تصادفی و ۲۰۰٬۰۰۰ تکرار تغییر کرد.
- قالب بکاپ به نسخهٔ ۲ ارتقا یافت؛ بکاپ‌های قدیمی (نسخهٔ ۱) قابل بازیابی نیستند.
- تست‌ها: بررسی قالب جدید، نمک/IV تصادفی، و تشخیص دستکاری (authenticity).

### تمیزکاری و هم‌راستا کردن
- حذف کد مردهٔ `HomeCoordinatorV2`/`HomeCoordinatorFactory` و provider مربوطه؛ `HomeCoordinator` اصلی (پیاده‌ساز Portها) تنها مسیر است.
- حذف `FeatureFlags.hasRiskyPlatformFeatureEnabled` (بلااستفاده در تولید).
- هم‌راستا کردن `lib/app_config.dart` با `android/app/build.gradle.kts` و `pubspec.yaml` (packageName و نسخه).
- افزودن `docs/KNOWN_GAPS.md`: نقشهٔ راه تکمیل شکاف‌های شناخته‌شده (LLM محلی، Vosk، iOS، وب).

## 1.0.0+1 — انتشار رسمی 🎉 (فاز نهایی)

### آماده انتشار
- نسخه 1.0.0+1
- امضای release با key.properties (fallback به debug اگر فایل نباشد)
- آیکون اختصاصی دستیار (assets/icon/icon.png) با flutter_launcher_icons
- مدل 3D تعاملی (assistant.glb) داخل APK
- مغز یکپارچه + حافظه بلندمدت + پیش‌بینی ۳۰ روزه + بازخورد
- کاراکتر سه‌بعدی با دفتر یادداشت
- دستیار مرکز همه اطلاعات (show_all_data)
- 34 تست، 29 intent، 10 feature flag


## 0.2.5+8 — توانایی حل مسئله: برنامهٔ پرداخت بدهی با یادگیری (فاز ۴۰.۶)

### اضافه شده
- `WorkLearningService`: یادگیری عادت کاری کاربر از سابقه — میانگین دقیقهٔ کار در روز، میانگین درآمد ساعتی و «توان درآمدی روزانه».
- `DebtRepaymentPlanner`: موتور حل مسئلهٔ پرداخت — مجموع بدهی، اولویت پرداخت (فوری‌ترین مهلت اول، سپس مبلغ)، درآمد و ساعت لازم در روز، امکان‌سنجی، تاریخ پایان تخمینی با توان یادگرفته‌شده.
- دستیار با intent «برنامه پرداخت بدهی» پاسخ می‌دهد: «مجموع بدهی‌هایت... اولویت پرداخت: ۱. علی... روزی X تومان در بیاور... با روند فعلیات حدود تاریخ Y تموم می‌شود».
- فرمان صوتی چندبدهی: «به علی و محمد و حسن بدهکارم، به علی ۲۰ میل، به محمد پنج میل و به حسن یک میل، تا ماه آینده» → ثبت دسته‌ای + محاسبهٔ فوری برنامه.
- پارسر مهلت «ماه»: «تا ماه آینده»، «تا ۲ ماه دیگه» در فرمان صوتی.
- تست‌ها: `work_learning_service_test.dart`، `debt_repayment_planner_test.dart` + تست دستیار.

### اصلاح شده
- `AssistantContext`: فیلدهای `debts` و `workProfile` اضافه شد.
- `app_providers`: دستیار به بدهی‌های فعال و پروفایل کاری متصل شد.

## 0.2.4+7 — تشخیص گفتار آفلاین با Vosk (فاز ۴۰.۵)

### اضافه شده
- انتزاع `VoiceInput` با دو موتور: `OnlineVoiceInput` (سرویس گوشی، رفتار قبلی) و `OfflineVoskVoiceInput` (Vosk — کاملاً آفلاین).
- `VoskModelLocator`: پیدا کردن مدل فارسی از assets یا دایرکتوری اسناد.
- `scripts/download_vosk_model.sh`: دانلود `vosk-model-small-fa-0.4` (~۴۰MB).
- فعال‌سازی با `--dart-define=ENABLE_OFFLINE_SPEECH=true`؛ بدون مدل، خودکار به سرویس آنلاین برمی‌گردد.
- ProGuard rules برای JNA (موردنیاز Vosk) + فعال‌سازی minify در release.
- تست `vosk_model_locator_test.dart` (انتخاب موتور + یابندهٔ مدل).

### اصلاح شده
- `home_screen.dart` حالا از `VoiceInputFactory` استفاده می‌کند (به‌جای `SpeechToText` مستقیم) — موتور در UI نمایش داده می‌شود.

## 0.2.3+6 — رفع ناقصی‌ها: برنامه‌ریزی با ساعت کاری + پاکسازی (فاز ۴۰.۴)

### اضافه شده
- دستیار حالا «برنامهٔ امروز» را با رعایت ساعت کاری و روزهای تعطیل کاربر می‌چیند (`TimeAwarePlanner` به دستیار وصل شد — قبلاً بلااستفاده بود).
- تست جدید برای این قابلیت در `local_assistant_test.dart`.

### اصلاح شده
- یادداشت قدیمی تب دستیار (می‌گفت LLM هنوز وصل نشده) → وضعیت واقعی (LLM محلی پشتیبانی می‌شود و در بالای صفحه نشان داده می‌شود).
- `docs/KNOWN_BUILD_RISKS.md`: مقدمهٔ قدیمی «build اجرا نشده» → وضعیت فعلی.
- `docs/AI_UPGRADE.md`: بخش «قدم بعدی» منسوخ (MethodChannel) → ارجاع به روش فعلی (شیم C).
- `release/release_candidate_checklist.md`: موارد تأییدشده علامت خوردند (analyze، تست‌ها، permissionها).

## 0.2.2+5 — سمت اندروید کامل برای LLM (فاز ۴۰.۳)

### اضافه شده
- پوشهٔ `android/` کامل و نسخه‌دار: `AndroidManifest.xml` با همهٔ permissionها (میکروفون، تقویم، اعلان، دقیق، boot) + برچسب فارسی + ساختار `jniLibs/arm64-v8a`.
- `scripts/build_android_llm.sh`: ساخت خودکار llama.cpp و شیم C با NDK و قراردادن در jniLibs.
- کتابخانه‌های بومی arm64 واقعاً با NDK r27c ساخته و تست شدند (`libllama.so`، `libggml*.so`، `libllm_shim.so`).
- CI دیگر `flutter create` اجرا نمی‌کند (تا Manifest سفارشی بازنویسی نشود).

### اصلاح شده
- `android/.gitignore`: gradle-wrapper.jar و gradlew حالا نسخه‌دار می‌شوند (برای بیلد ضروری).
- `android_templates/AndroidManifest_permissions.xml` به‌روزرسانی شد.

## 0.2.1+4 — اتصال واقعی LLM محلی (فاز ۴۰.۲)

### اضافه شده
- اتصال واقعی به llama.cpp با مدل Qwen2.5 0.5B (GGUF) — کاملاً آفلاین و بدون API.
- شیم C (`tool/csrc/llm_shim.c`): پل امن FFI که کل inference را سمت C نگه می‌دارد (حل مشکل ABI توابع struct-return).
- `LlamaCppBackend` (FFI) + `LlamaModelLocator` + `LlamaAssetInstaller` (کپی مدل از asset).
- ابزار تست زنده `tool/llm_smoke.dart` + اسکریپت‌های `download_llm_model.sh` و `build_llm_shim.sh`.
- فعال‌سازی با `--dart-define=ENABLE_LOCAL_LLM=true`؛ بدون مدل، دستیار خودکار روی موتور قانون‌محور می‌ماند.
- پاک‌سازی KV cache بین درخواست‌ها (llama_memory_seq_rm).
- تست‌های واحد `llama_backend_test.dart` (یافتن مدل، fallback، خطاها).

### اصلاح شده
- وابستگی `llama_cpp_dart` → `ffi` (شیم مستقیم).

## 0.2.0+3 — ارتقای هوش مصنوعی: معماری هیبرید (فاز ۴۰)

### اضافه شده
- موتور پردازش زبان فارسی (`persian_nlu.dart`): نرمال‌سازی حروف/اعداد/نیم‌فاصله + تشخیص قصد با امتیازدهی.
- بازنویسی دستیار قانون‌محور با ~۱۷ قصد: بهترین کار بعدی، برنامه امروز/هفته، عقب‌ماندگی، ریسک (کاری + مالی)، انجام‌های امروز، پیش‌بینی درآمد، وضعیت بودجه، توصیه مالی، بهترین زمان کار عمیق، برنامه جبران، انگیزه، راهنما و…
- معماری هیبرید LLM: `HybridLocalAssistant` + `LlmBackend` + `MethodChannelLlmBackend` با fallback خودکار و timeout. مسیر LLM با flag `ENABLE_LOCAL_LLM` (پیش‌فرض خاموش) کنترل می‌شود.
- هوش برنامه‌ریزی: برنامهٔ هفته (`buildWeekPlan`)، پنجره‌های کار عمیق (`bestDeepWorkWindows`)، برنامهٔ جبران (`catchUpPlan`).
- هوش مالی: `FinanceInsightsService` — تشخیص هزینهٔ غیرعادی نسبت به ۳۰ روز قبل، توصیهٔ مالی، ریسک مالی.
- دستیار حالا به دادهٔ مالی کاربر هم متصل است (درآمد ساعتی، بودجه، ریسک) — همه چیز محلی و بدون API.
- ۵ فایل تست جدید (~۳۵ تست) + مستندات `docs/AI_UPGRADE.md`.

### اصلاح شده
- `dart format` استاندارد روی فایل‌های جدید + اصلاح لینت‌های جدید.

## 0.1.1+2 — تکمیل Feature Flags و پاکسازی لینت (فاز ۳۹+)

### اضافه شده
- Feature Flags حالا واقعاً روی رفتار برنامه اثر می‌گذارند: با `--dart-define` می‌توانی فرمان صوتی، پاسخ صوتی، تقویم، PDF، اشتراک فایل، هشدارهای هوشمند و بکاپ رمزنگاری‌شده را خاموش کنی (در بیلد امن/دیباگ).
- تست ویجت گیتینگ: `test/feature_gating_widget_test.dart` ثابت می‌کند flagها در هر دو حالت روشن و خاموش درست کار می‌کنند.
- گام CI برای تأیید گیتینگ با همه flagهای خاموش در `flutter_ci.yml`.
- قفل `pubspec.lock` برای بیلدهای تکرارپذیر.

### اصلاح شده
- استفاده از `TableHelper.fromTextArray` به‌جای API منسوخشده `Table.fromTextArray` در PDF.
- افزودن `@override`های ازدست‌رفته و حذف ایمپورت‌های بلااستفاده (لینت از ۸۷ مورد به صفر رسید).
- رفع deprecation های `speech_to_text` (انتقال `localeId`/`listenFor`/`pauseFor` به `SpeechListenOptions`).
- فرمت‌بندی چند خط نامرتب در `home_screen.dart`.

## 0.1.0+1 — MVP تا فاز ۱۲

### اضافه شده
- مدیریت کارها، برنامه روزانه و اولویت‌بندی هوشمند
- حسابدار شخصی، درآمد، هزینه، درآمد ساعتی
- فرمان صوتی فارسی و پاسخ صوتی زن/مرد
- تاریخ شمسی، اعداد فارسی و تومان
- SQLite، نوتیفیکیشن محلی، گزارش مالی
- هدف درآمدی روزانه و ماه شمسی
- هزینه‌های آینده، بدهی و طلب
- پاکت پول، بودجه‌بندی دسته‌بندی‌ها
- مکالمه چندمرحله‌ای، سناریوسازی، ریسک‌سنجی
- تأیید عملیات حساس و نمودارهای مالی
- تقویم گوشی، PDF، اشتراک فایل
- فونت Vazirmatn، اسکریپت‌های build و QA
- CI/CD با GitHub Actions

### نیازمند تست واقعی
- اجرای `flutter analyze`
- اجرای تست‌ها
- تست فرمان صوتی روی Android/iOS
- تست تقویم، PDF و اشتراک‌گذاری فایل روی گوشی واقعی
