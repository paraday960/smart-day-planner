import 'dart:io';

import 'package:path/path.dart' as p;

import 'llama_backend.dart' show getAppDocumentsDirectory;

/// نام فایل مدل فارسی Vosk (زیپ).
const String kVoskModelFileName = 'vosk-model-small-fa-0.4.zip';

/// نام فایل مدل داخل zip (پوشهٔ استخراج‌شده).
const String kVoskModelDirName = 'vosk-model-small-fa-0.4';

/// کمترین حجم قابل قبول برای فایل مدل (زیپ ~۳۵MB).
const int _minModelBytes = 1 << 20; // 1MB

/// پیدا کردن مدل Vosk روی دستگاه.
///
/// ترتیب جستجو:
/// 1. `--dart-define=VOSK_MODEL_PATH=/مسیر/مطلق` (برای توسعه)
/// 2. `<دایرکتوری اسناد>/vosk/<نام فایل>` (کاربر مدل را آنجا می‌گذارد)
/// 3. مدل باندل‌شده در `assets/models/` (اگر در build گنجانده شده باشد)
///
/// مدل Vosk به‌صورت zip است و `vosk_flutter` با [ModelLoader] آن را
/// استخراج می‌کند؛ این کلاس فقط مسیر فایل zip را پیدا می‌کند.
class VoskModelLocator {
  VoskModelLocator({Future<Directory> Function()? documentsDirProvider})
      : _documentsDirProvider =
            documentsDirProvider ?? _defaultDocumentsDir;

  final Future<Directory> Function() _documentsDirProvider;

  static const String envOverride = String.fromEnvironment('VOSK_MODEL_PATH');

  static Future<Directory> _defaultDocumentsDir() async {
    return Directory(await getAppDocumentsDirectory());
  }

  Future<String?> find({String? overridePath}) async {
    final candidates = <String>[
      if (overridePath != null && overridePath.isNotEmpty) overridePath,
      if (envOverride.isNotEmpty) envOverride,
    ];
    for (final candidate in candidates) {
      final file = File(candidate);
      if (_looksLikeModel(file)) return file.path;
    }

    // دایرکتوری اسناد
    final docsDir = await _documentsDirProvider();
    final inDocs = File(p.join(docsDir.path, 'vosk', kVoskModelFileName));
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
