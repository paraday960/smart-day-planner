# Changelog

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
