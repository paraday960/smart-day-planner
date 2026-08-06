# کتابخانه‌های بومی LLM (jniLibs)

این پوشه محل قرارگیری فایل‌های `.so` برای اجرای LLM محلی روی اندروید است.

## ساختار

```
jniLibs/
└── arm64-v8a/          ← گوشی‌های ۶۴بیتی (اکثر گوشی‌های امروزی)
    ├── libllm_shim.so  ← شیم C (tool/csrc/llm_shim.c)
    ├── libllama.so     ← llama.cpp (و وابستگی‌های ggml)
    ├── libggml.so
    ├── libggml-base.so
    └── libggml-cpu.so
```

## ساخت

اسکریپت `scripts/build_android_llm.sh` همه‌چیز را انجام می‌دهد
(نیازمند Android NDK است):

```bash
ANDROID_NDK=/path/to/ndk bash scripts/build_android_llm.sh
```

خروجی: فایل‌های `.so` در همین پوشه قرار می‌گیرند و در APK باندل می‌شوند.

> فایل‌های `.so` عمداً در گیت نیستند (حجم و وابستگی به NDK).
> این پوشه فقط ساختار را نگه می‌دارد.
