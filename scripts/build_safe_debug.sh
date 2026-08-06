#!/usr/bin/env bash
set -euo pipefail

# نسخه safe برای عیب‌یابی: قابلیت‌های پرریسک پلتفرمی با dart-define خاموش می‌شوند.
flutter pub get
flutter build apk --debug \
  --dart-define=ENABLE_CALENDAR=false \
  --dart-define=ENABLE_PDF_EXPORT=false \
  --dart-define=ENABLE_SHARE_FILES=false \
  --dart-define=ENABLE_SMART_NOTIFICATIONS=false

echo "Safe debug APK ساخته شد: build/app/outputs/flutter-apk/app-debug.apk"
