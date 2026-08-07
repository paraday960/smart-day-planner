import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'llama_backend.dart' show getAppDocumentsDirectory, kLlamaModelFileName;

/// نصب مدل GGUF از asset باندل‌شده به دایرکتوری اسناد (فقط سمت Flutter).
///
/// اگر مدل به‌عنوان asset در `assets/models/` باندل شده باشد،
/// این کلاس آن را یک‌بار به `<اسناد>/llm/` کپی می‌کند تا llama.cpp
/// بتواند مستقیم از مسیر فایل آن را بخواند.
///
/// مسیر نصب باید دقیقاً همان مسیری باشد که [LlamaModelLocator] جستجو می‌کند
/// (`<اسناد>/llm/<نام مدل>`) — به همین دلیل از `getAppDocumentsDirectory`
/// استفاده می‌شود نه `path_provider`، تا locator فایل نصب‌شده را پیدا کند.
class LlamaAssetInstaller {
  const LlamaAssetInstaller();

  static const String assetPath = 'assets/models/$kLlamaModelFileName';

  /// آیا مدل asset وجود دارد؟
  Future<bool> assetExists() async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.lengthInBytes >= (1 << 20);
    } catch (_) {
      return false;
    }
  }

  /// مدل asset را (اگر هنوز نصب نشده) به دایرکتوری اسناد کپی می‌کند.
  ///
  /// خروجی: مسیر فایل نصب‌شده، یا null اگر asset وجود نداشت.
  Future<String?> installIfNeeded() async {
    try {
      final docsDir = Directory(await getAppDocumentsDirectory());
      final targetDir = Directory(p.join(docsDir.path, 'llm'));
      final target = File(p.join(targetDir.path, kLlamaModelFileName));

      // اگر از قبل نصب شده، کاری نکن.
      if (target.existsSync() && target.lengthSync() >= (1 << 20)) {
        return target.path;
      }

      final data = await rootBundle.load(assetPath);
      if (data.lengthInBytes < (1 << 20)) return null;

      await targetDir.create(recursive: true);
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }
}
