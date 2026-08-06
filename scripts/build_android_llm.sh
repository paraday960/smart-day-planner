#!/usr/bin/env bash
# ساخت کتابخانه‌های بومی LLM برای اندروید (arm64-v8a)
#
# نیازمندی‌ها:
#   - Android NDK (r25 یا جدیدتر)
#   - cmake + ninja
#
# استفاده:
#   ANDROID_NDK=/path/to/android-ndk bash scripts/build_android_llm.sh
#
# خروجی: فایل‌های .so در android/app/src/main/jniLibs/arm64-v8a/
# که هنگام ساخت APK به‌طور خودکار باندل می‌شوند.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
NDK="${ANDROID_NDK:?متغیر ANDROID_NDK را بده (مسیر NDK)}"
ABI="arm64-v8a"
API_LEVEL="${ANDROID_API_LEVEL:-24}"
LLAMA_DIR="${LLAMA_CPP_DIR:-${PROJECT_DIR}/.build/llama.cpp}"

JNI_DIR="${PROJECT_DIR}/android/app/src/main/jniLibs/${ABI}"
mkdir -p "${JNI_DIR}"

echo "═══ ساخت LLM بومی برای اندروید (${ABI}) ═══"
echo "NDK: ${NDK}"
echo "llama.cpp: ${LLAMA_DIR}"

# ۱) دانلود llama.cpp اگر موجود نیست
if [ ! -d "${LLAMA_DIR}" ]; then
  echo "[۱/۴] دانلود llama.cpp..."
  mkdir -p "$(dirname "${LLAMA_DIR}")"
  git clone --depth 1 https://github.com/ggerganov/llama.cpp "${LLAMA_DIR}"
fi

# ۲) ساخت کتابخانه‌های llama/ggml با NDK
echo "[۲/۴] ساخت llama.cpp با NDK (cmake + ninja)..."
cmake -S "${LLAMA_DIR}" -B "${LLAMA_DIR}/build-android" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="${NDK}/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="${ABI}" \
  -DANDROID_PLATFORM="android-${API_LEVEL}" \
  -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF \
  -DGGML_CUDA=OFF \
  -DGGML_METAL=OFF \
  -DLLAMA_CURL=OFF \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "${LLAMA_DIR}/build-android" -j1 --target llama

# ۳) ساخت شیم C (llm_shim.c) با کامپایلر NDK
echo "[۳/۴] ساخت llm_shim.so..."
NDK_CC="${NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API_LEVEL}-clang"
if [ ! -x "${NDK_CC}" ]; then
  echo "❌ کامپایلر NDK پیدا نشد: ${NDK_CC}"
  exit 1
fi

LLAMA_BIN="${LLAMA_DIR}/build-android/bin"
"${NDK_CC}" -O2 -shared -fPIC "${PROJECT_DIR}/tool/csrc/llm_shim.c" \
  -I "${LLAMA_DIR}/include" \
  -I "${LLAMA_DIR}/ggml/include" \
  -L "${LLAMA_BIN}" -lllama \
  -o "${JNI_DIR}/libllm_shim.so"

# ۴) کپی کتابخانه‌های llama/ggml به jniLibs
echo "[۴/۴] کپی کتابخانه‌ها به jniLibs..."
cp -P "${LLAMA_BIN}/libllama.so"* "${JNI_DIR}/"
cp -P "${LLAMA_BIN}/libggml.so"* "${JNI_DIR}/"
cp -P "${LLAMA_BIN}/libggml-base.so"* "${JNI_DIR}/"
cp -P "${LLAMA_BIN}/libggml-cpu.so"* "${JNI_DIR}/"

echo
echo "✅ کتابخانه‌های اندروید آماده شدند:"
ls -lh "${JNI_DIR}"
echo
echo "حالا اپ را با LLM بسازید:"
echo "  flutter build apk --release --dart-define=ENABLE_LOCAL_LLM=true"
echo
echo "⚠️  مدل GGUF را هم روی گوشی بگذارید (assets/models/ یا دایرکتوری اسناد):"
echo "  bash scripts/download_llm_model.sh"
