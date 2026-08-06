#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${1:-ir.smartday.planner}"
APP_NAME="${2:-دستیار روزانه ایرانی}"

echo "Package name پیشنهادی: $PACKAGE_NAME"
echo "App name پیشنهادی: $APP_NAME"
echo ""
echo "بعد از اجرای flutter create، این موارد را بررسی کن:"
echo "1) android/app/build.gradle یا build.gradle.kts: applicationId را روی $PACKAGE_NAME بگذار."
echo "2) android/app/src/main/AndroidManifest.xml: android:label را روی $APP_NAME بگذار."
echo "3) Permission ها را از android_templates/AndroidManifest_permissions.xml اضافه کن."
echo "4) برای انتشار عمومی، keystore بساز و signingConfig را تنظیم کن."
