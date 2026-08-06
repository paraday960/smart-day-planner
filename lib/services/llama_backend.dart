import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../app/feature_flags.dart';

/// خطای مربوط به عدم دسترسی به LLM (باید به fallback برگردد).
class LlmNotAvailableException implements Exception {
  const LlmNotAvailableException([this.message = 'LLM در دسترس نیست']);
  final String message;

  @override
  String toString() => message;
}

/// یک «پشتیبان» (backend) اجرای مدل زبانی محلی.
///
/// پیاده‌سازی واقعی فعلی [LlamaCppBackend] است که از طریق شیم C
/// (llm_shim.c) با llama.cpp کار می‌کند. برای تست، [FakeLlmBackend]
/// در test/fakes قرار دارد.
abstract class LlmBackend {
  /// آیا مدل بارگذاری شده و آمادهٔ پاسخ است؟
  Future<bool> get available;

  /// اجرای inference و برگرداندن متن کامل پاسخ.
  /// اگر خطا بدهد، لایهٔ هیبرید به موتور قانون‌محور برمی‌گردد.
  Future<String> generate(String prompt);
}

/// نام فایل پیش‌فرض مدل GGUF که `scripts/download_llm_model.sh` دانلود می‌کند.
const String kLlamaModelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';

/// کمترین حجم قابل قبول برای فایل مدل (مثلاً > ۱ مگابایت).
const int _minModelBytes = 1 << 20;

/// پیدا کردن فایل مدل GGUF روی دستگاه.
///
/// ترتیب جستجو:
/// 1. `--dart-define=LLM_MODEL_PATH=/مسیر/مطلق` (برای تست و توسعه)
/// 2. `<دایرکتوری اسناد>/llm/<نام مدل>` (کاربر مدل را آنجا می‌گذارد)
///
/// اگر مدل به‌عنوان asset باندل شده باشد، [LlamaAssetInstaller]
/// (در فایل جدا، سمت Flutter) آن را به دایرکتوری اسناد کپی می‌کند.
class LlamaModelLocator {
  LlamaModelLocator({Future<Directory> Function()? documentsDirProvider})
      : _documentsDirProvider =
            documentsDirProvider ?? _defaultDocumentsDir;

  final Future<Directory> Function() _documentsDirProvider;

  static const String envOverride = String.fromEnvironment('LLM_MODEL_PATH');

  static Future<Directory> _defaultDocumentsDir() async {
    return Directory(await getAppDocumentsDirectory());
  }

  Future<String?> find({String? overridePath}) async {
    // ۱) override صریح (dart-define یا پارامتر)
    final candidates = <String>[
      if (overridePath != null && overridePath.isNotEmpty) overridePath,
      if (envOverride.isNotEmpty) envOverride,
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (_looksLikeModel(file)) return file.path;
    }

    // ۲) دایرکتوری اسناد
    final docsDir = await _documentsDirProvider();
    final inDocs = File(p.join(docsDir.path, 'llm', kLlamaModelFileName));
    if (_looksLikeModel(inDocs)) return inDocs.path;

    return null;
  }

  bool _looksLikeModel(File file) {
    try {
      return file.existsSync() && file.lengthSync() >= _minModelBytes;
    } catch (_) {
      return false;
    }
  }
}

/// دایرکتوری اسناد برنامه (ساختار ساده برای اجتناب از وابستگی مستقیم).
Future<String> getAppDocumentsDirectory() async {
  final fromEnv = Platform.environment['APP_DOCUMENTS_DIR'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return p.join(home, 'Documents');
}

/// بکاند واقعی llama.cpp برای [LlmBackend].
///
/// از شیم C (`tool/csrc/llm_shim.c`) استفاده می‌کند که کل inference را
/// سمت C انجام می‌دهد؛ به همین دلیل فقط چند تابع ساده FFI لازم است و
/// مشکل ABI توابع struct-return وجود ندارد.
class LlamaCppBackend implements LlmBackend {
  LlamaCppBackend({
    String? modelPath,
    String? libraryPath,
    this.contextSize = 512,
    this.maxTokens = 256,
    this.temperature = 0.5,
    this.timeout = const Duration(seconds: 120),
    bool? enabled,
  })  : _modelPath = modelPath,
        _libraryPath = libraryPath,
        _enabled = enabled ?? FeatureFlags.enableLocalLlm;

  final String? _modelPath;
  final String? _libraryPath;
  final bool _enabled;
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  static const String envLibraryPath = String.fromEnvironment('LLM_LIB_PATH');

  /// نام تابع‌های شیم.
  static const _symLoad = 'shim_load';
  static const _symGenerate = 'shim_generate';
  static const _symFree = 'shim_free';

  DynamicLibrary? _lib;
  bool _libChecked = false;
  Pointer<Void>? _handle;
  String? _loadedModelPath;

  /// مسیر کتابخانهٔ بومی (شیم).
  String resolveLibraryPath() {
    final lib = _libraryPath;
    if (lib != null && lib.isNotEmpty) return lib;
    if (envLibraryPath.isNotEmpty) return envLibraryPath;
    // Android: از jniLibs لود می‌شود؛ بقیه: از مسیر جستجوی سیستمی.
    return 'libllm_shim.so';
  }

  DynamicLibrary _openLibrary() {
    final cached = _lib;
    if (cached != null) return cached;
    final lib = DynamicLibrary.open(resolveLibraryPath());
    _lib = lib;
    return lib;
  }

  @override
  Future<bool> get available async {
    if (!_enabled) return false;
    try {
      final path = await LlamaModelLocator().find(overridePath: _modelPath);
      if (path == null) return false;
      if (!_libChecked) {
        _openLibrary();
        _libChecked = true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> generate(String prompt) async {
    if (!_enabled) {
      throw const LlmNotAvailableException('LLM محلی غیرفعال است');
    }
    final path = await LlamaModelLocator().find(overridePath: _modelPath);
    if (path == null) {
      throw const LlmNotAvailableException('فایل مدل پیدا نشد');
    }
    final lib = _openLibrary();

    final handle = await _ensureLoaded(lib, path);

    final promptPtr = _formatChatPrompt(prompt).toNativeUtf8();
    final out = calloc<Uint8>(_maxOutBytes);
    try {
      final generate = lib
          .lookupFunction<
              Int32 Function(
                  Pointer<Void>, Pointer<Utf8>, Int32, Pointer<Uint8>, Int32),
              int Function(
                  Pointer<Void>, Pointer<Utf8>, int, Pointer<Uint8>, int)>(
            _symGenerate);
      final written = generate(
        handle,
        promptPtr,
        maxTokens,
        out,
        _maxOutBytes,
      );
      if (written < 0) {
        throw LlmNotAvailableException('خطای تولید LLM (کد $written)');
      }
      final bytes = out.asTypedList(written);
      return _cleanupOutput(utf8.decode(bytes));
    } finally {
      calloc.free(out);
      malloc.free(promptPtr);
    }
  }

  static const int _maxOutBytes = 8192;

  Future<Pointer<Void>> _ensureLoaded(DynamicLibrary lib, String modelPath) async {
    final existing = _handle;
    if (existing != null && _loadedModelPath == modelPath) return existing;

    // مدل قبلی را آزاد کن
    _freeHandle();

    final load = lib.lookupFunction<
        Pointer<Void> Function(Pointer<Utf8>, Int32, Int32, Float),
        Pointer<Void> Function(Pointer<Utf8>, int, int, double)>(
      _symLoad,
    );
    final pathPtr = modelPath.toNativeUtf8();
    try {
      final handle = load(pathPtr, contextSize, 2, temperature);
      if (handle == nullptr) {
        throw const LlmNotAvailableException('بارگذاری مدل ناموفق بود');
      }
      _handle = handle;
      _loadedModelPath = modelPath;
      return handle;
    } finally {
      malloc.free(pathPtr);
    }
  }

  void _freeHandle() {
    final lib = _lib;
    final handle = _handle;
    _handle = null;
    _loadedModelPath = null;
    if (lib == null || handle == null) return;
    try {
      final free = lib.lookupFunction<
          Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        _symFree,
      );
      free(handle);
    } catch (_) {}
  }

  /// بستن مدل و آزاد کردن حافظه.
  Future<void> dispose() async {
    _freeHandle();
    _lib = null;
    _libChecked = false;
  }

  /// قالب‌بندی ChatML برای مدل‌های Qwen.
  String _formatChatPrompt(String userPrompt) {
    return '<|im_start|>system\n'
        'تو یک دستیار برنامه‌ریزی روزانهٔ ایرانی هستی. پاسخ فارسی، کوتاه، دوستانه و عملی بده.\n'
        '<|im_end|>\n'
        '<|im_start|>user\n'
        '$userPrompt\n'
        '<|im_end|>\n'
        '<|im_start|>assistant\n';
  }

  /// پاک‌سازی خروجی: حذف توکن‌های پایان و فاصله‌های اضافی.
  String _cleanupOutput(String text) {
    var out = text.trim();
    final imEnd = out.indexOf('<|im_end|>');
    if (imEnd >= 0) out = out.substring(0, imEnd);
    out = out.replaceAll('<|endoftext|>', '').trim();
    return out;
  }
}
