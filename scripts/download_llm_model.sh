#!/usr/bin/env bash
# دانلود مدل LLM محلی برای دستیار هوشمند (Qwen2.5 0.5B Instruct — GGUF Q4_K_M)
#
# استفاده:
#   bash scripts/download_llm_model.sh
#
# مدل در assets/models/ قرار می‌گیرد تا در بیلد باندل شود.
# حجم تقریبی: ~۴۷۰ مگابایت.
#
# بعد از دانلود، اپ را با LLM روشن بسازید:
#   flutter build apk --release --dart-define=ENABLE_LOCAL_LLM=true
#
# مجوز: Qwen2.5 تحت Apache 2.0 منتشر شده است.
set -euo pipefail

MODEL_NAME="qwen2.5-0.5b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/${MODEL_NAME}"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/models"
DEST="${DEST_DIR}/${MODEL_NAME}"

mkdir -p "${DEST_DIR}"

if [ -f "${DEST}" ] && [ -s "${DEST}" ]; then
  echo "مدل از قبل موجود است: ${DEST}"
  ls -lh "${DEST}"
  exit 0
fi

echo "در حال دانلود مدل: ${MODEL_NAME}"
echo "از: ${MODEL_URL}"
curl -L --fail --progress-bar -o "${DEST}" "${MODEL_URL}"

echo
echo "✅ مدل دانلود شد:"
ls -lh "${DEST}"
echo
echo "برای فعال‌سازی LLM در بیلد:"
echo "  flutter build apk --release --dart-define=ENABLE_LOCAL_LLM=true"
