# شکاف‌ها و ناقصی‌های شناخته‌شده + نقشهٔ راه تکمیل

> این سند مواردی را فهرست می‌کند که در کد «ادعا/آماده» شده‌اند ولی هنوز کامل نیستند،
> و قدم‌های عملی برای تکمیل آن‌ها. بخشی از آن‌ها فقط با ابزار Flutter و دانلود
> مدل‌ها (نه در سندباکس) قابل انجام است.

## ۱. 🔴 LLM محلی (llama.cpp) — فقط زیرساخت، اجرا نمی‌شود

**وضعیت:** کد کامل است (`lib/services/llama_backend.dart`، شیم C در
`tool/csrc/llm_shim.c`، `LlamaAssetInstaller`)، ولی:

- هیچ کتابخانهٔ باینری (`libllama.so`) داخل `android/app/src/main/jniLibs/` نیست
  (پوشه‌ها فقط `.gitkeep` دارند).
- هیچ مدل GGUF داخل `assets/models/` نیست (فقط `assistant.glb`).
- فلگ `ENABLE_LOCAL_LLM` پیش‌فرض `false` است → دستیار همیشه به موتور قانون‌محور
  برمی‌گردد.

**قدم‌های تکمیل:**
1. با `scripts/download_llm_model.sh` مدل `qwen2.5-0.5b-instruct-q4_k_m.gguf` را دانلود و در
   `assets/models/` قرار بده.
2. `libllama.so` را برای هر ABI (arm64-v8a, armeabi-v7a, x86_64) از
   `scripts/build_llm_shim.sh` بساز و در `android/app/src/main/jniLibs/<abi>/` بگذار.
3. build با `--dart-define=ENABLE_LOCAL_LLM=true` انجام بده.

## ۲. 🔴 تشخیص گفتار آفلاین (Vosk) — فعال نیست

**وضعیت:** `OfflineVoskVoiceInput` و `VoskModelLocator` آماده‌اند، ولی مدل فارسی
(~۴۰MB) باندل نشده و فلگ `ENABLE_OFFLINE_SPEECH` خاموش است → عملاً از سرویس
آنلاین گوشی استفاده می‌شود (پس «بدون اینترنت برای گفتار» هنوز برقرار نیست).

**قدم:** `scripts/download_vosk_model.sh` را اجرا و مسیر مدل را در
`vosk_model_locator.dart` مشخص کن؛ با `--dart-define=ENABLE_OFFLINE_SPEECH=true`
build بگیر.

## ۳. 🔴 پوشهٔ iOS — وجود ندارد

**وضعیت:** ریپو فقط Android دارد (`ios/` در ریپو نیست). README ادعای «Android و
iOS از یک کد مشترک» دارد ولی iOS قابل ساخت نیست.

**قدم:** در یک محیط دارای Flutter:
```bash
flutter create --platforms=ios --project-name smart_day_planner .
```
سپس `ios/Runner/Info.plist` را با توضیحات میکروفون، Speech Recognition و
Calendar (نمونه در `android_templates/`) تکمیل کن و `device_calendar`,
`flutter_tts`, `speech_to_text` را در Podfile/قفل نسخه بگذار.

## ۴. 🟡 خروجی وب / شبیه‌ساز — اسکلت ناتمام

**وضعیت:** پوشهٔ `web/` فقط دو آیکن دارد؛ `index.html`, `manifest.json` و
بوت‌استرپ Flutter تولید نشده‌اند. README به «شبیه‌ساز وب» اشاره دارد ولی کار نمی‌کند.

**قدم:** در محیط دارای Flutter: `flutter create --platforms=web .` تا فایل‌های
وب تولید شوند، سپس قابلیت‌های پلتفرمی (میکروفون/نوتیفیکیشن/تقویم) را در وب
غیرفعال یا جایگزین کن.

## ۵. 🟡 پیام‌های «هنوز به فرمان صوتی وصل نشده» در VoiceCommandProcessor

**وضعیت:** در `lib/services/voice_command_processor.dart` چند intent وقتی
repository مربوطه null باشد فقط پیام فارسی برمی‌گردانند (پاکت پول، بدهی/طلب،
هزینه‌های آینده، هدف‌ها). این پیام‌ها «طراحی دفاعی» هستند، ولی باید اطمینان حاصل
شود در مسیر تولید هیچ‌کدام با null صدا زده نشوند (`AutonomousAgentService` باید
همیشه همهٔ repoها را پاس بدهد).

**قدم:** یک تست اضافه کن که فرمان‌های این intentها را با همهٔ repoها اجرا و
نشان دهد که پیام «وصل نشده» برنمی‌گردد.

## ۶. 🟡 فایل‌های بزرگ — refactor جزئی

`lib/services/local_assistant.dart` (~۱۱۲۵ خط) و `voice_command_processor.dart`
(~۱۰۷۵ خط) هنوز بزرگ‌اند. پیشنهاد: استخراج intent handlerها و ابزار NLU به
فایل‌های جدا (همان الگوی refactor بقیهٔ پروژه).

## ۷. 🟢 موارد پیکربندی که تصحیح شدند

- `lib/app_config.dart` با گریدل/pubspec هم‌راستا شد (packageName، version).
- کد مردهٔ `HomeCoordinatorV2`/`HomeCoordinatorFactory` و provider مربوطه حذف شد؛
  `HomeCoordinator` اصلی (که همان Portها را پیاده می‌کند) تنها مسیر است.
- `FeatureFlags.hasRiskyPlatformFeatureEnabled` (بلااستفاده در تولید) حذف شد.

## یادداشت: ایمیل پشتیبانی
`AppConfig.supportEmail` خالی است؛ قبل از انتشار واقعی مقدار واقعی بگذار تا در UI
نمایش داده شود.
