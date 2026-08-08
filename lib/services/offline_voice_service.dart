import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس گفتار فارسی آفلاین (Piper + sherpa-onnx).
///
/// منطق «دانلود به‌موقع»:
/// - اول بررسی می‌کند آیا مدل فارسی قبلاً دانلود و نصب شده یا نه.
/// - اگر نه، مدل (tar.bz2) را از اینترنت دانلود و استخراج می‌کند.
/// - بعد متن فارسی را به صوت تبدیل و پخش می‌کند — کاملاً آفلاین.
///
/// برنامه‌ی اصلی ابتدا موتور گفتار سیستم (flutter_tts) را امتحان می‌کند و فقط
/// وقتی آن نتواند فارسی صحبت کند، از این سرویس استفاده می‌شود.
class OfflineVoiceService {
  OfflineVoiceService._();
  static final OfflineVoiceService instance = OfflineVoiceService._();

  static const _readyKey = 'piper_fa_model_ready';
  static const _versionKey = 'piper_fa_model_version';
  static const _modelVersion = '1';

  /// آدرس دانلود مدل فارسی Piper (amir-medium).
  static const String modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'vits-piper-fa_IR-amir-medium.tar.bz2';

  static const String _dirName = 'vits-piper-fa_IR-amir-medium';

  bool _installed = false;
  bool _checking = false;
  Directory? _modelDir;
  sherpa.OfflineTts? _tts;
  bool _bindingsInitialized = false;

  /// آیا مدل فارسی دانلود و آماده است؟
  bool get isInstalled => _installed;

  /// آیا در حال بررسی/دانلود است؟
  bool get isChecking => _checking;

  Future<void> _initBindings() async {
    if (_bindingsInitialized) return;
    sherpa.initBindings();
    _bindingsInitialized = true;
  }

  Future<Directory> _appDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelRoot = Directory('${dir.path}/piper_fa');
    if (!await modelRoot.exists()) await modelRoot.create(recursive: true);
    return modelRoot;
  }

  /// بررسی نصب بودن مدل (بر اساس flag ذخیره‌شده + وجود فایل‌ها).
  ///
  /// اگر در حال دانلود است، تا [timeoutSeconds] صبر می‌کند و اگر تمام نشد
  /// false برمی‌گرداند تا UI بلاک نشود.
  Future<bool> ensureInstalled({int timeoutSeconds = 300}) async {
    if (_installed) return true;
    if (_checking) {
      for (var i = 0; i < timeoutSeconds; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (_installed) return true;
        if (!_checking) return false;
      }
      return false;
    }

    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ready = prefs.getBool(_readyKey) ?? false;
      final version = prefs.getString(_versionKey) ?? '';
      final root = await _appDocumentsDir();
      final dir = Directory('${root.path}/$_dirName');
      final onnx = File('${dir.path}/fa_IR-amir-medium.onnx');
      final tokens = File('${dir.path}/tokens.txt');
      final espeak = Directory('${dir.path}/espeak-ng-data');

      if (ready && version == _modelVersion && onnx.existsSync() &&
          tokens.existsSync() && espeak.existsSync()) {
        _installed = true;
        _modelDir = dir;
        return true;
      }

      // دانلود و نصب
      await _downloadAndExtract(dir);
      await prefs.setBool(_readyKey, true);
      await prefs.setString(_versionKey, _modelVersion);
      _installed = true;
      _modelDir = dir;
      return true;
    } catch (e) {
      debugPrint('OfflineVoiceService: دانلود/نصب مدل ناموفق بود: $e');
      return false;
    } finally {
      _checking = false;
    }
  }

  Future<void> _downloadAndExtract(Directory destDir) async {
    debugPrint('OfflineVoiceService: در حال دانلود مدل فارسی (~64MB)...');
    // ۱) دانلود
    final tmpFile = File('${destDir.parent.path}/piper_fa_model.tar.bz2');
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(modelUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception('خطای دانلود مدل (HTTP ${response.statusCode})');
    }
    final sink = tmpFile.openWrite();
    await response.pipe(sink);
    await sink.close();
    httpClient.close(force: true);

    // ۲) استخراج tar.bz2 با پکیج archive
    debugPrint('OfflineVoiceService: استخراج مدل...');
    await extractTarBz2(tmpFile.path, destDir.parent.path);
    if (!await destDir.exists()) {
      throw Exception('استخراج مدل ناموفق بود؛ پوشه ساخته نشد.');
    }
    // ۳) پاک‌سازی فایل فشرده
    try {
      if (await tmpFile.exists()) await tmpFile.delete();
    } catch (_) {}
  }

  /// ساخت و نگهداری نمونهٔ TTS.
  Future<sherpa.OfflineTts> _getTts() async {
    if (_tts != null) return _tts!;
    await _initBindings();
    final dir = _modelDir;
    if (dir == null) {
      final ok = await ensureInstalled();
      if (!ok) throw Exception('مدل فارسی آماده نیست');
    }

    final d = _modelDir!;
    final model = sherpa.OfflineTtsVitsModelConfig(
      model: '${d.path}/fa_IR-amir-medium.onnx',
      tokens: '${d.path}/tokens.txt',
      dataDir: '${d.path}/espeak-ng-data',
    );
    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: model,
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    );
    final config = sherpa.OfflineTtsConfig(model: modelConfig);
    final tts = sherpa.OfflineTts(config);
    _tts = tts;
    return tts;
  }

  /// تبدیل متن فارسی به فایل WAV و پخش آن.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    final ok = await ensureInstalled(timeoutSeconds: 90);
    if (!ok) throw Exception('مدل فارسی در دسترس نیست');

    final tts = await _getTts();
    final audio = tts.generateWithConfig(
      text: text,
      config: const sherpa.OfflineTtsGenerationConfig(
        sid: 0,
        speed: 1.0,
        silenceScale: 0.2,
      ),
    );
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw Exception('صدایی تولید نشد');
    }

    // ذخیره به WAV
    final wavFile = File('${(await _appDocumentsDir()).path}/piper_output.wav');
    sherpa.writeWave(
      filename: wavFile.path,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );

    // پخش
    final player = AudioPlayer();
    try {
      await player.setFilePath(wavFile.path);
      await player.play();
    } finally {
      player.dispose();
    }
  }

  /// آزادسازی منابع.
  Future<void> dispose() async {
    _tts?.free();
    _tts = null;
  }
}

// ──────────────────────────── پشتیبانی استخراج tar.bz2 ────────────────────

/// استخراج یک بایگانی tar.bz2 به پوشهٔ مقصد.
Future<void> extractTarBz2(String tarBz2Path, String destPath) async {
  final bytes = await File(tarBz2Path).readAsBytes();
  // bzip2 decompress
  final bz2 = BZip2Decoder().decodeBytes(bytes);
  // tar decode
  final archive = TarDecoder().decodeBytes(bz2);

  final normalizedDest = Directory(destPath).absolute.path;

  for (final file in archive) {
    // نام فایل می‌تواند با «/» شروع شود؛ نرمال کن.
    var rel = file.name;
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    if (rel.isEmpty) continue; // پوشهٔ ریشه

    final outFile = File('$destPath/$rel');
    // ایمن‌سازی: فقط درون destPath.
    final normalizedOut = outFile.absolute.path;
    if (!normalizedOut.startsWith(normalizedDest)) {
      continue;
    }

    // فایل‌های بدون محتوا (دایرکتوری/پیوند) را رد کن؛ دایرکتوری‌ها هنگام
    // ساخت والد به‌صورت خودکار ساخته می‌شوند.
    final content = file.content;
    if (content is Uint8List && content.isNotEmpty) {
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(content, flush: true);
    }
  }
}
