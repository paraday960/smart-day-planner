import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'llama_backend.dart';

/// نصب مدل GGUF از asset باندل‌شده به دایرکتوری اسناد (فقط سمت Flutter).
///
/// اگر مدل به‌عنوان asset در `assets/models/` باندل شده باشد،
/// این کلاس آن را یک‌بار به `<اسناد>/llm/` کپی می‌کند تا llama.cpp
/// بتواند مستقیم از مسیر فایل آن را بخواند.
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
      final docsDir = await getApplicationDocumentsDirectory();
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
