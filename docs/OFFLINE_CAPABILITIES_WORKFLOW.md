# راهنمای workflow «Offline Capabilities Build» (Vosk + LLM)

> **چرا این فایل اینجاست؟** توکن GitHub App که روی این ریپو کار می‌کند مجوز
> `workflows` ندارد و نمی‌تواند فایل‌های `.github/workflows/*` را push کند.
> محتوای دقیق workflow در این سند نگهداری می‌شود تا بتوانید آن را دستی اضافه
> کنید — یا اگر به اپ اجازهٔ **Workflows (read/write)** در
> `Settings → Integrations → GitHub Apps` بدهید، در سشن بعدی push می‌شود.

## هدف

ساخت APK با قابلیت‌های آفلاین کامل (شکاف‌های ۱ و ۲ در `KNOWN_GAPS.md`):

- **تشخیص گفتار آفلاین فارسی (Vosk)** — دانلود خودکار مدل (~۴۰MB) روی runner
  و باندل در APK با `ENABLE_OFFLINE_SPEECH=true`.
- **LLM محلی (llama.cpp + Qwen2.5 0.5B)** — اختیاری (~۴۷۰MB) از طریق input
  workflow؛ باندل در APK با `ENABLE_LOCAL_LLM=true`.

مدل‌ها داخل ریپو commit نمی‌شوند (حجمشان خیلی بزرگ است و `assets/models/*.zip`
و `*.gguf` عمداً gitignore شده‌اند)؛ workflow آن‌ها را موقع build دانلود و به
pubspec اضافه می‌کند.

## روش اضافه کردن

فایل زیر را با نام `.github/workflows/offline_capabilities.yml` در ریپو بسازید
(محتوا را کپی کنید):

```yaml
name: Offline Capabilities Build (Vosk + LLM)

# ساخت APK با قابلیت‌های آفلاین کامل:
#   - تشخیص گفتار آفلاین فارسی (Vosk) — دانلود خودکار مدل ~۴۰MB روی runner
#   - LLM محلی (llama.cpp + Qwen2.5 0.5B) — اختیاری، ~۴۷۰MB، از طریق input
#
# استفاده: تب Actions → این workflow → Run workflow
# خروجی: artifact شامل APK دیباگ با فرمان صوتی آفلاین (و LLM در صورت درخواست).

on:
  workflow_dispatch:
    inputs:
      include_llm:
        description: 'همراه با LLM محلی (دانلود ~۴۷۰MB مدل + APK حدود ۵۰۰MB)'
        required: true
        default: false
        type: boolean

jobs:
  build-offline-apk:
    name: Build Offline APK
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      # ── دانلود مدل‌ها (روی runner اینترنت آزاد است) ──
      - name: Download Vosk model (فارسی ~۴۰MB)
        run: bash scripts/download_vosk_model.sh

      - name: Download LLM model (Qwen2.5 0.5B ~۴۷۰MB)
        if: inputs.include_llm == 'true'
        run: bash scripts/download_llm_model.sh

      # ── اضافه کردن مدل‌ها به pubspec assets ──
      - name: Patch pubspec assets with model files
        run: |
          python3 <<'PY'
          from pathlib import Path

          pubspec = Path('pubspec.yaml')
          text = pubspec.read_text()

          anchor = '    - assets/models/assistant.glb\n'
          assert anchor in text, 'anchor not found in pubspec assets'

          entries = ['    - assets/models/vosk-model-small-fa-0.4.zip']
          # LLM فقط وقتی دانلود شده که include_llm=true باشد
          if Path('assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf').exists():
              entries.append('    - assets/models/qwen2.5-0.5b-instruct-q4_k_m.gguf')

          changed = False
          for entry in entries:
              if entry + '\n' not in text:
                  text = text.replace(anchor, anchor + entry + '\n')
                  changed = True
                  print('added to pubspec:', entry)

          if changed:
              pubspec.write_text(text)

          # چک: فایل‌های مدل حتماً وجود دارند تا flutter بیلد نشکند
          for entry in entries:
              path = entry.strip()
              assert Path(path).exists(), f'missing model file: {path}'
              print('model present:', path)
          PY

      - name: Enable Android desugaring (idempotent)
        run: |
          python3 <<'PY'
          from pathlib import Path
          import re
          kotlin = Path('android/app/build.gradle.kts')
          if kotlin.exists():
              text = kotlin.read_text()
              if 'isCoreLibraryDesugaringEnabled' not in text:
                  text = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', text, count=1)
                  print('Added isCoreLibraryDesugaringEnabled = true')
              if 'desugar_jdk_libs' not in text:
                  text = text.replace('dependencies {', 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")', 1)
                  print('Added desugar_jdk_libs')
              kotlin.write_text(text)
          else:
              groovy = Path('android/app/build.gradle')
              if groovy.exists():
                  text = groovy.read_text()
                  if 'coreLibraryDesugaringEnabled' not in text:
                      text = re.sub(r'compileOptions\s*\{', 'compileOptions {\n        coreLibraryDesugaringEnabled true', text, count=1)
                  if 'desugar_jdk_libs' not in text:
                      text = text.replace('dependencies {', "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'", 1)
                  groovy.write_text(text)
                  print('Groovy desugaring patched')
          PY

      - name: Clean up auto-generated widget_test
        run: |
          if [ -f test/widget_test.dart ]; then
            if grep -q "MyApp" test/widget_test.dart; then
              rm -f test/widget_test.dart
              echo "Removed conflicting auto-generated widget_test.dart"
            fi
          fi

      - name: Get dependencies
        run: flutter pub get

      - name: Run unit tests
        run: flutter test --exclude-tags=needs-real-device

      - name: Build offline debug APK
        run: |
          LLM_FLAG=""
          if [ "${{ inputs.include_llm }}" == "true" ]; then
            LLM_FLAG="--dart-define=ENABLE_LOCAL_LLM=true"
          fi
          flutter build apk --debug \
            --dart-define=ENABLE_OFFLINE_SPEECH=true \
            $LLM_FLAG \
            --dart-define=ENABLE_CALENDAR=false \
            --dart-define=ENABLE_PDF_EXPORT=false \
            --dart-define=ENABLE_SHARE_FILES=false \
            --dart-define=ENABLE_SMART_NOTIFICATIONS=false

      - name: Upload offline debug APK
        uses: actions/upload-artifact@v4
        with:
          name: smart-day-planner-offline-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
```

## استفاده

1. تب **Actions** → **Offline Capabilities Build (Vosk + LLM)** → **Run workflow**.
2. برای APK سبک با فقط فرمان صوتی آفلاین: تیک `include_llm` را بر ندارید.
3. برای APK کامل با LLM محلی: تیک `include_llm` را بزنید (دانلود ~۴۷۰MB،
   APK حدود ۵۰۰MB).
4. از **Artifacts** آخرین ران، `smart-day-planner-offline-apk` را دانلود کنید.

## نکتهٔ مهم دربارهٔ Vosk روی دستگاه

مدل Vosk (~۴۰MB) داخل APK باندل می‌شود و در اولین اجرا توسط `VoskAssetInstaller`
به `<اسناد>/vosk/` کپی می‌شود تا `VoskModelLocator` پیدایش کند. اگر مدل را
نخواستید داخل APK باشد، کافیست zip را دستی در `<اسناد>/vosk/` بگذارید (همان
مسیر را locator جستجو می‌کند).
