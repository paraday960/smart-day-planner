import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'llama_backend.dart' show getAppDocumentsDirectory;
import 'vosk_model_locator.dart' show kVoskModelFileName;

/// نصب مدل Vosk (زیپ) از asset باندل‌شده به دایرکتوری اسناد (فقط سمت Flutter).
///
/// اگر مدل به‌عنوان asset در `assets/models/` باندل شده باشد (مثلاً در بیلد
/// CI که `scripts/download_vosk_model.sh` را اجرا می‌کند)، این کلاس آن را
/// یک‌بار به `<اسناد>/vosk/` کپی می‌کند تا [VoskModelLocator] پیدایش کند و
/// تشخیص گفتار آفلاین واقعاً بدون اینترنت کار کند.
///
/// مسیر نصب باید دقیقاً همان مسیری باشد که [VoskModelLocator] جستجو می‌کند
/// (`<اسناد>/vosk/<نام فایل>`) — به همین دلیل از `getAppDocumentsDirectory`
/// استفاده می‌شود نه `path_provider`، تا با locator هماهنگ بماند.
class VoskAssetInstaller {
  const VoskAssetInstaller();

  static const String assetPath = 'assets/models/$kVoskModelFileName';

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
      final targetDir = Directory(p.join(docsDir.path, 'vosk'));
      final target = File(p.join(targetDir.path, kVoskModelFileName));

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
