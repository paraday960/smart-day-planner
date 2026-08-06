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
