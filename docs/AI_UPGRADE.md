# ارتقای هوش مصنوعی — معماری هیبرید (فاز ۴۰)

این سند تغییرات هوش مصنوعی برنامه را بعد از فاز ۳۹ توضیح می‌دهد.

## هدف

اپ سبک و آفلاین بماند، ولی دستیار «باهوش‌تر» شود و برای اتصال LLM واقعی آماده باشد:

- **موتور قانون‌محور** به‌عنوان پایه: بدون هیچ API و بدون حجم اضافه، پاسخ‌های مفید و قابل توضیح.
- **لایهٔ LLM اختیاری**: اگر روزی مدل محلی (llama.cpp / ONNX / TFLite) اضافه شد، دستیار خودکار از آن استفاده می‌کند و اگر در دسترس نبود به موتور قانونی برمی‌گردد.

## معماری جدید

```text
                    ┌─────────────────────────────┐
   prompt + tasks → │  HybridLocalAssistant        │
                    │  (LocalLlmAdapter)           │
                    └──────────────┬──────────────┘
                         │                       │
              ┌──────────▼─────────┐   ┌─────────▼──────────────┐
              │  LlmBackend?       │   │ RuleBasedLocalAssistant │
              │  (MethodChannel)   │   │ (fallback، همیشه هست)   │
              └────────────────────┘   └─────────┬──────────────┘
                                                 │
                                   ┌─────────────▼──────────────┐
                                   │ PersianNlu (نرمال‌سازی +    │
                                   │ تشخیص قصد با امتیازدهی)      │
                                   └─────────────┬──────────────┘
                                                 │
                                   ┌─────────────▼──────────────┐
                                   │ SmartPlanner + Finance      │
                                   │ Insights + Forecast         │
                                   └────────────────────────────┘
```

## فایل‌های جدید/تغییر یافته

| فایل | نقش |
|---|---|
| `lib/services/persian_nlu.dart` | نرمال‌سازی متن فارسی (عربی→فارسی، اعداد، نیم‌فاصله) + تطبیق الگو + تشخیص قصد با امتیازدهی |
| `lib/services/local_assistant.dart` | بازنویسی `RuleBasedLocalAssistant` با ~۱۷ قصد (سلام، راهنما، بهترین کار بعدی، برنامه امروز/هفته، عقب‌ماندگی، ریسک، انجام‌های امروز، درآمد، بودجه، توصیه مالی، بهترین زمان، جبران، انگیزه و…) + زمینهٔ مالی اختیاری |
| `lib/services/hybrid_local_assistant.dart` | `LlmBackend` (interface)، `MethodChannelLlmBackend`، `HybridLocalAssistant` با fallback و timeout |
| `lib/services/finance_insights_service.dart` | تحلیل مالی pure: تشخیص هزینهٔ غیرعادی (نسبت به ۳۰ روز قبل)، توصیه‌ها، ریسک |
| `lib/services/smart_planner.dart` | `buildWeekPlan`، `bestDeepWorkWindows`، `catchUpPlan` |
| `lib/app/feature_flags.dart` | flag جدید `ENABLE_LOCAL_LLM` (پیش‌فرض خاموش) |
| `lib/app/app_providers.dart` | `assistantProvider` (هیبرید با زمینهٔ مالی) |

## تست‌ها

- `test/persian_nlu_test.dart` — نرمال‌سازی و تشخیص قصد
- `test/local_assistant_test.dart` — پاسخ‌های دستیار (با زمینهٔ مالی هم)
- `test/hybrid_local_assistant_test.dart` — مسیر LLM، fallback، خطا، timeout
- `test/smart_planner_ai_test.dart` — برنامهٔ هفته، پنجره‌های کار عمیق، جبران
- `test/finance_insights_test.dart` — تشخیص هزینهٔ غیرعادی، توصیه، ریسک

## اتصال LLM واقعی (قدم بعدی)

۱. یک مدل GGUF آماده کن (مثلاً Qwen2.5 0.5B Q4 — حدود ۴۰۰ مگابایت).

۲. سمت Android/iOS channel با نام `ir.smartday.planner/llm` را پیاده کن:
   - `isAvailable` → bool (مدل بارگذاری شده؟)
   - `generate({prompt})` → String

۳. مدل را asset کن و `flutter run --dart-define=ENABLE_LOCAL_LLM=true` بزن.

۴. اگر از پکیج `llama_cpp_dart` استفاده می‌کنی، کافی است `MethodChannelLlmBackend` را با یک `LlamaLlmBackend` جایگزین کنی — بقیهٔ منطق (fallback، timeout، prompt) آماده است.

## اصل حریم خصوصی

داده‌ها همچنان فقط روی گوشی می‌ماند؛ هیچ چیزی به سرور ارسال نمی‌شود. این اصل در `LLM_OFFLINE.md` هم تأکید شده است.

---

## اتصال LLM واقعی — کامل شد (فاز ۴۰.۲)

LLM محلی واقعاً متصل و تست شد:

### معماری نهایی
```text
Dart (Flutter)
  └─ LlamaCppBackend (FFI)  ← lib/services/llama_backend.dart
       └─ libllm_shim.so    ← tool/csrc/llm_shim.c (کامپایل‌شده)
            └─ libllama.so  ← llama.cpp
                 └─ qwen2.5-0.5b-instruct-q4_k_m.gguf (مدل)
```

چرا شیم C جدا؟
- binding های FFI مستقیم از llama.h با توابع struct-return (مثل
  `llama_context_default_params`) روی ABI لینوکس/اندروید ناسازگارند و کرش می‌کنند.
- شیم کل inference را سمت C نگه می‌دارد و فقط توابع ساده (pointer/int/char*)
  به Dart می‌دهد — هیچ مشکل ABI باقی نمی‌ماند.

### فایل‌های کلیدی
| فایل | نقش |
|---|---|
| `tool/csrc/llm_shim.c` | شیم C: بارگذاری مدل، ساخت sampler chain، تولید متن، پاک‌کردن KV cache بین درخواست‌ها |
| `lib/services/llama_backend.dart` | `LlamaCppBackend` (FFI) + `LlamaModelLocator` (یافتن مدل) + `LlmBackend` |
| `lib/services/llama_asset_installer.dart` | کپی مدل از asset به دایرکتوری اسناد (اگر باندل شده باشد) |
| `tool/llm_smoke.dart` | تست زندهٔ CLI با مدل واقعی |
| `scripts/download_llm_model.sh` | دانلود Qwen2.5 0.5B GGUF (~۴۷۰MB) از HuggingFace |
| `scripts/build_llm_shim.sh` | ساخت libllm_shim.so از llama.cpp |

### فعال‌سازی
```bash
# ۱) دانلود مدل
bash scripts/download_llm_model.sh

# ۲) ساخت شیم (بعد از ساخت llama.cpp)
LLAMA_CPP_DIR=/path/to/llama.cpp bash scripts/build_llm_shim.sh

# ۳) تست زنده
dart run tool/llm_smoke.dart \
  --model=assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  --lib=scripts/libllm_shim.so

# ۴) بیلد اپ با LLM روشن
flutter build apk --release --dart-define=ENABLE_LOCAL_LLM=true
```

### نتیجهٔ تست واقعی (روی CPU، Qwen2.5 0.5B Q4)
- پرسش «سلام! خوبی؟» → پاسخ فارسی در ~۲ ثانیه
- پرسش «بهترین کار بعدی چیه؟» (با لیست کارها) → پاسخ ساخت‌یافته در ~۶ ثانیه
- پرسش «چطور ۴ ساعت کار درآمدزا برنامه بریزم؟» → راهکار در ~۶ ثانیه
- حافظهٔ KV بین درخواست‌ها پاک می‌شود (llama_memory_seq_rm) تا context پر نشود.
- حجم مدل: ~۴۷۰MB؛ RAM لازم: ~۶۰۰MB؛ روی گوشی‌های میان‌رده قابل اجراست.

### نکتهٔ کیفیت
Qwen2.5 0.5B کوچک است و پاسخ‌هایش رسمی/کلی است؛ برای کیفیت بالاتر
مدل‌های بزرگ‌تر (Qwen2.5 1.5B یا 3B Q4 — حدود ۱ تا ۲GB) را می‌توان
جایگزین کرد بدون تغییر کد (فقط نام فایل در `kLlamaModelFileName`).
