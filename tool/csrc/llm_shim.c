// llm_shim.c — پل C بین Dart (FFI) و llama.cpp
//
// چرا این فایل لازم است؟
//   binding های FFI که مستقیم از llama.h تولید می‌شوند با توابعی که
//   struct های بزرگ را برمی‌گردانند (مثل llama_context_default_params)
//   روی ABI لینوکس/اندروید (sret) ناسازگارند و کرش می‌کنند.
//   این شیم کل inference را سمت C نگه می‌دارد و فقط توابع ساده
//   (int / pointer / char*) به Dart می‌دهد.
//
// ساخت (لینوکس):
//   gcc -O2 -shared -fPIC llm_shim.c \
//       -I <llama.cpp>/include -I <llama.cpp>/ggml/include \
//       -L <libdir> -lllama -Wl,-rpath,<libdir> \
//       -o libllm_shim.so
//
// برای اندروید (arm64) با NDK مشابه کامپایل و خروجی را در
// android/app/src/main/jniLibs/arm64-v8a/ بگذارید.

#include "llama.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    struct llama_model * model;
    struct llama_context * ctx;
    struct llama_sampler * smpl;
    int n_ctx;
} shim_llm;

int shim_version(void) {
    return 1;
}

// بارگذاری مدل و ساخت context + sampler chain.
// خروجی: هندل (pointer) یا NULL در صورت خطا.
void * shim_load(const char * model_path, int n_ctx, int n_threads, float temperature) {
    if (model_path == NULL) return NULL;

    llama_backend_init();

    struct llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 0;      // فقط CPU
    mp.load_mode    = LLAMA_LOAD_MODE_MMAP;

    struct llama_model * model = llama_model_load_from_file(model_path, mp);
    if (model == NULL) {
        return NULL;
    }

    if (n_ctx <= 0) n_ctx = 512;
    if (n_threads <= 0) n_threads = 2;

    struct llama_context_params cp = llama_context_default_params();
    cp.n_ctx           = (uint32_t) n_ctx;
    cp.n_batch         = 256;
    cp.n_ubatch        = 256;
    cp.n_threads       = n_threads;
    cp.n_threads_batch = n_threads;

    struct llama_context * ctx = llama_init_from_model(model, cp);
    if (ctx == NULL) {
        llama_model_free(model);
        return NULL;
    }

    llama_sampler_chain_params sp = llama_sampler_chain_default_params();
    struct llama_sampler * smpl = llama_sampler_chain_init(sp);
    if (temperature > 0.0f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
    }
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.9f, 1));
    // sampler پایانی: انتخاب نهایی از توزیع فیلترشده (اجباری است)
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(42));

    shim_llm * llm = (shim_llm *) calloc(1, sizeof(shim_llm));
    if (llm == NULL) {
        llama_sampler_free(smpl);
        llama_free(ctx);
        llama_model_free(model);
        return NULL;
    }
    llm->model = model;
    llm->ctx   = ctx;
    llm->smpl  = smpl;
    llm->n_ctx = n_ctx;
    return llm;
}

// تولید متن از روی prompt آماده‌شده (قالب ChatML).
// خروجی: تعداد بایت‌های نوشته‌شده در out (بدون null ترمیناتور) یا منفی در خطا.
int shim_generate(void * handle, const char * prompt, int max_tokens, char * out, int out_cap) {
    if (handle == NULL || prompt == NULL || out == NULL) return -1;
    shim_llm * llm = (shim_llm *) handle;
    const struct llama_vocab * vocab = llama_model_get_vocab(llm->model);
    const llama_token eos = llama_vocab_eos(vocab);

    // پاک کردن حافظهٔ KV از درخواست قبلی تا context پر نشود
    llama_memory_seq_rm(llama_get_memory(llm->ctx), -1, -1, -1);

    if (max_tokens <= 0) max_tokens = 128;
    if (out_cap <= 0) return -2;

    // توکن‌سازی prompt
    const int n_max_tok = 8192;
    llama_token * tokens = (llama_token *) malloc(sizeof(llama_token) * n_max_tok);
    if (tokens == NULL) return -3;

    const int n_tok = llama_tokenize(vocab, prompt, (int) strlen(prompt),
                                     tokens, n_max_tok, true, true);
    if (n_tok < 0) {
        free(tokens);
        return -4;
    }

    int n_past = 0;
    const int n_batch = 256;

    // decode اولیه prompt (در تکه‌های n_batch)
    for (int i = 0; i < n_tok; i += n_batch) {
        const int n = (n_tok - i < n_batch) ? (n_tok - i) : n_batch;
        llama_batch batch = llama_batch_get_one(&tokens[i], n);
        if (llama_decode(llm->ctx, batch) != 0) {
            free(tokens);
            return -5;
        }
        n_past += n;
        if (n_past >= llm->n_ctx - 16) break;
    }

    // حلقهٔ تولید
    int written = 0;
    for (int step = 0; step < max_tokens; step++) {
        llama_token tok = llama_sampler_sample(llm->smpl, llm->ctx, -1);
        if (tok == eos) break;

        char piece[64];
        const int plen = llama_token_to_piece(vocab, tok, piece, (int) sizeof(piece), 0, false);
        if (plen > 0) {
            if (written + plen >= out_cap) break;
            memcpy(out + written, piece, plen);
            written += plen;
            // اگر نشانگر پایان گفتگو ساخته شد، همین جا قطع کن
            out[written] = '\0';
            char * im_end = strstr(out, "<|im_end|>");
            if (im_end != NULL) {
                written = (int) (im_end - out);
                break;
            }
        }

        llama_sampler_accept(llm->smpl, tok);

        llama_batch batch = llama_batch_get_one(&tok, 1);
        if (llama_decode(llm->ctx, batch) != 0) break;
        n_past++;
        if (n_past >= llm->n_ctx - 4) break;
    }

    out[written] = '\0';
    free(tokens);
    return written;
}

void shim_free(void * handle) {
    if (handle == NULL) return;
    shim_llm * llm = (shim_llm *) handle;
    if (llm->smpl)  llama_sampler_free(llm->smpl);
    if (llm->ctx)   llama_free(llm->ctx);
    if (llm->model) llama_model_free(llm->model);
    free(llm);
}
