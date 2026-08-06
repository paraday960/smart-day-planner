#!/usr/bin/env bash
# ساخت کتابخانهٔ شیم C (libllm_shim.so) که Dart با آن به llama.cpp وصل می‌شود.
#
# استفاده (لینوکس):
#   LLAMA_CPP_DIR=/path/to/llama.cpp bash scripts/build_llm_shim.sh
#
# خروجی: libllm_shim.so (در همین پوشه)
#
# برای اندروید (arm64) با NDK مشابه:
#   CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang \
#     LLAMA_CPP_DIR=... bash scripts/build_llm_shim.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="${SCRIPT_DIR}/../tool/csrc/llm_shim.c"

LLAMA_CPP_DIR="${LLAMA_CPP_DIR:?متغیر LLAMA_CPP_DIR را بده (مسیر llama.cpp)}"
OUT_DIR="${LLAMA_OUT_DIR:-${SCRIPT_DIR}}"
CC="${CC:-gcc}"

mkdir -p "${OUT_DIR}"

"${CC}" -O2 -shared -fPIC "${SRC}" \
  -I "${LLAMA_CPP_DIR}/include" \
  -I "${LLAMA_CPP_DIR}/ggml/include" \
  -L "${LLAMA_LIB_DIR:-${LLAMA_CPP_DIR}/build/bin}" -lllama \
  -Wl,-rpath,"${LLAMA_LIB_DIR:-${LLAMA_CPP_DIR}/build/bin}" \
  -o "${OUT_DIR}/libllm_shim.so"

echo "✅ شیم ساخته شد: ${OUT_DIR}/libllm_shim.so"
echo
echo "برای تست زنده:"
echo "  dart run tool/llm_smoke.dart --model=/path/to/qwen2.5-0.5b-instruct-q4_k_m.gguf --lib=${OUT_DIR}/libllm_shim.so"
