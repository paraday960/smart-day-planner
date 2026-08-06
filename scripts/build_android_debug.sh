#!/usr/bin/env bash
set -euo pipefail
flutter pub get
flutter build apk --debug
echo "APK دیباگ آماده است: build/app/outputs/flutter-apk/app-debug.apk"
