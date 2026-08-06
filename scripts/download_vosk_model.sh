#!/usr/bin/env bash
# دانلود مدل تشخیص گفتار آفلاین فارسی (Vosk) — ~۴۰ مگابایت
#
# استفاده:
#   bash scripts/download_vosk_model.sh
#
# خروجی: assets/models/vosk-model-small-fa-0.4.zip
# (برای باندل شدن در اپ؛ یا می‌توانید فایل را در
#  دایرکتوری اسناد گوشی/llm قرار دهید)
#
# بعد از دانلود، اپ را با تشخیص آفلاین بسازید:
#   flutter build apk --release --dart-define=ENABLE_OFFLINE_SPEECH=true
#
# مجوز: Vosk مدل‌ها را تحت Apache 2.0 منتشر می‌کند.
set -euo pipefail

MODEL_NAME="vosk-model-small-fa-0.4"
MODEL_URL="https://alphacephei.com/vosk/models/${MODEL_NAME}.zip"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/models"
DEST="${DEST_DIR}/${MODEL_NAME}.zip"

mkdir -p "${DEST_DIR}"

if [ -f "${DEST}" ] && [ -s "${DEST}" ]; then
  echo "مدل از قبل موجود است: ${DEST}"
  ls -lh "${DEST}"
  exit 0
fi

echo "در حال دانلود مدل: ${MODEL_NAME}.zip"
curl -L --fail --progress-bar -o "${DEST}" "${MODEL_URL}"

echo
echo "✅ مدل دانلود شد:"
ls -lh "${DEST}"
echo
echo "برای فعال‌سازی تشخیص گفتار آفلاین در بیلد:"
echo "  flutter build apk --release --dart-define=ENABLE_OFFLINE_SPEECH=true"
echo
echo "اگر نمی‌خواهید مدل داخل APK برود، فایل zip را در"
echo "دایرکتوری اسناد گوشی/vosk/ بگذارید تا همان‌جا خوانده شود."
