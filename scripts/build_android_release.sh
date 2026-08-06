#!/usr/bin/env bash
set -euo pipefail

# از ریشه پروژه اجرا کن:
# bash scripts/build_android_release.sh

flutter clean
flutter pub get
flutter analyze
flutter build apk --release

echo "APK آماده است: build/app/outputs/flutter-apk/app-release.apk"
