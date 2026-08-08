# شکاف‌ها و ناقصی‌های شناخته‌شده + نقشهٔ راه تکمیل

> این سند مواردی را فهرست می‌کند که در کد «ادعا/آماده» شده‌اند ولی هنوز کامل نیستند،
> و قدم‌های عملی برای تکمیل آن‌ها. بخشی از آن‌ها فقط با ابزار Flutter و دانلود
> مدل‌ها (نه در سندباکس) قابل انجام است.
>
> آخرین به‌روزرسانی: **2026-08-07** — شکاف‌های ۴، ۵ و ۶ بسته شدند؛
> شکاف‌های ۱ و ۲ «قابل ساخت» شدند (workflow جدید CI)؛ شکاف ۳ اسکلت iOS اضافه شد.

## ۱. 🟡 LLM محلی (llama.cpp) — زیرساخت کامل + workflow ساخت؛ مدل داخل ریپو نیست

**وضعیت:** ✅ کد کامل و هماهنگ شد؛ تنها «مدل فیزیکی» هنوز داخل ریپو نیست:

- `LlamaAssetInstaller` اصلاح شد تا مدل را به همان مسیری کپی کند که
  `LlamaModelLocator` جستجو می‌کند (`<اسناد>/llm/`) — قبلش مسیرها ناهماهنگ بودند
  و مدل باندل‌شده هیچ‌وقت پیدا نمی‌شد.
- `main.dart` هنگام `ENABLE_LOCAL_LLM=true` مدل asset را یک‌بار نصب می‌کند.
- **Workflow `.github/workflows/offline_capabilities.yml`** (از 2026-08-08 در
  ریپو موجود است) مدل `qwen2.5-0.5b-instruct-q4_k_m.gguf` (~۴۷۰MB) را روی
  runner دانلود، به pubspec اضافه و داخل APK باندل می‌کند (input اختیاری
  `include_llm`).

**چرا مدل داخل ریپو نیست؟** حجمش (~۴۷۰MB) از سقف فایل گیت‌هاب (>100MB) بیشتر است.

**قدم‌های باقی‌مانده:**
1. تب Actions → `Offline Capabilities Build` → Run workflow → تیک `include_llm`.
2. (اختیاری) `libllama.so` برای هر ABI با `scripts/build_android_llm.sh`
   (نیازمند Android NDK؛ خروجی .so با `.gitignore` پوشیده شده و نباید commit شود).

## ۲. 🟡 تشخیص گفتار آفلاین (Vosk) — کد کامل + workflow ساخت؛ مدل داخل ریپو نیست

**وضعیت:** ✅ زنجیرهٔ کامل شد:

- `VoskAssetInstaller` جدید (مثل LlamaAssetInstaller) مدل باندل‌شده را به
  `<اسناد>/vosk/` کپی می‌کند — دقیقاً همان مسیری که `VoskModelLocator` جستجو
  می‌کند (قبلاً locator اصلاً asset را چک نمی‌کرد).
- `main.dart` هنگام `ENABLE_OFFLINE_SPEECH=true` مدل را یک‌بار نصب می‌کند.
- Workflow `offline_capabilities.yml` (موجود در ریپو از 2026-08-08) مدل فارسی
  (~۴۰MB) را موقع build دانلود و باندل می‌کند و APK با
  `ENABLE_OFFLINE_SPEECH=true` می‌سازد.

**چرا مدل داخل ریپو نیست؟** ~۴۰MB حجمش با وجود امکان commit، ریپو را سنگین
می‌کند و `assets/models/*.zip` عمداً gitignore شده؛ دانلود هنگام ساخت تمیزتر است.

**قدم باقی‌مانده:** تب Actions → `Offline Capabilities Build` → Run workflow
(بدون LLM کافی است؛ APK ~۸۰MB).

## ۳. 🟡 پوشهٔ iOS — اسکلت استاندارد اضافه شد؛ نیاز به تأیید در محیط Flutter

**وضعیت:** پوشهٔ کامل `ios/` اضافه شد (قالب استاندارد Flutter):
`Runner.xcodeproj` (پروژهٔ Xcode با UUID های سازگار)، `AppDelegate.swift`،
`Info.plist` با دسترسی‌های میکروفون/گفتار/تقویم، `Podfile`، storyboard ها و
asset catalog.

**قدم باقی‌مانده (تأیید نهایی):** در یک محیط دارای Flutter/Xcode:
```bash
flutter create --platforms=ios --project-name smart_day_planner .
flutter build ios --simulator
```
(دستور بالا فقط برای هم‌سنجی اسکلت است؛ فایل‌های سفارشی ما (Info.plist و...)
را بازنویسی می‌کند، پس اگر تغییری ندادید از git برگردانید یا فقط ساختار را چک کنید.)

## ۴. 🟢 خروجی وب — اسکلت کامل شد

**وضعیت:** ✅ `web/index.html`، `web/manifest.json` و `web/flutter_bootstrap.js`
اضافه شدند (قالب استاندارد Flutter 3.22+؛ آیکن‌های موجود `icon-192/512.png`
استفاده می‌شوند). با `flutter create --platforms=web .` هیچ فایلی از دست نمی‌رود.

**قدم باقی‌مانده (بهینه):** قابلیت‌های پلتفرمی (میکروفون/نوتیفیکیشن/تقویم) در
وب — در `web/` پیاده‌سازی پلتفرم ندارند و هنگام اجرای وب به‌صورت امن fallback
می‌شوند؛ اگر خواستید نسخهٔ وب کامل شود، این‌ها را با فایل‌های پلتفرمی dart جایگزین کن.

## ۵. 🟢 پیام‌های «هنوز به فرمان صوتی وصل نشده» — تست اضافه شد

**وضعیت:** ✅ تست جدید `test/voice_command_all_repos_test.dart` با **همهٔ**
repositoryها (goal، plannedExpense، debt، allocation، memory) همهٔ intent های
دارای این پیام دفاعی را اجرا می‌کند (پاکت پول، بدهی/پرداخت/چندبدهی، هزینهٔ آینده،
هدف، سناریوهای پیش‌بینی) و تضمین می‌کند هیچ‌کدام پیام «وصل نشده» برنگردانند.
یک تست هم قرارداد پیام دفاعی را در حالت repo های null نگه می‌دارد.

## ۶. 🟢 فایل‌های بزرگ — refactor جزئی انجام شد

**وضعیت:** ✅
- `lib/services/voice_command_processor.dart`: **1081 → 707 خط** — همهٔ ابزارهای
  NLU خالص (نرمال‌سازی، مبلغ، نام، مهلت، ...) به `lib/services/voice_nlu.dart`
  (`VoiceNlu` — کلاس static) منتقل شدند.
- `lib/services/local_assistant.dart`: **1109 → 692 خط** — لیست intent ها
  (۴۲۰ خط) به `lib/services/local_assistant_intents.dart`
  (`kRuleBasedAssistantIntents`) منتقل شد.

**قدم بعدی (اختیاری):** استخراج intent handler های `VoiceCommandProcessor`
به کلاس‌های جدا (مثل الگوی بقیهٔ پروژه)؛ حالا که ابزارها جدا شده‌اند، کم‌ریسک‌تر شده.

## ۷. 🟢 موارد پیکربندی که تصحیح شدند

- `lib/app_config.dart` با گریدل/pubspec هم‌راستا شد (packageName، version).
- کد مردهٔ `HomeCoordinatorV2`/`HomeCoordinatorFactory` و provider مربوطه حذف شد؛
  `HomeCoordinator` اصلی تنها مسیر است.
- `FeatureFlags.hasRiskyPlatformFeatureEnabled` (بلااستفاده در تولید) حذف شد.
- مسیر نصب `LlamaAssetInstaller` با `LlamaModelLocator` هماهنگ شد (باگ پیدا نشدن
  مدل باندل‌شده).

## یادداشت: ایمیل پشتیبانی
`AppConfig.supportEmail` خالی است؛ قبل از انتشار واقعی مقدار واقعی بگذار تا در UI
نمایش داده شود.
