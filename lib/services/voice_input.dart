import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vosk_flutter/vosk_flutter.dart';

import '../app/feature_flags.dart';
import 'vosk_model_locator.dart';

/// انتزاع ورودی صدای کاربر.
///
/// دو پیاده‌سازی دارد:
/// - [OnlineVoiceInput]: سرویس تشخیص گفتار خود گوشی (می‌تواند آنلاین باشد)
/// - [OfflineVoskVoiceInput]: Vosk — کاملاً آفلاین
abstract class VoiceInput {
  /// راه‌اندازی سرویس. خروجی: آیا آماده است؟
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  /// شروع گوش دادن.
  Future<void> start({
    required void Function(String partialText) onPartial,
    required void Function(double level) onSoundLevel,
    required void Function(String finalText) onResult,
  });

  /// پایان گوش دادن و گرفتن نتیجهٔ نهایی.
  Future<void> stop();

  /// لغو گوش دادن.
  Future<void> cancel();

  bool get isListening;
  bool get isReady;

  /// نام موتور برای نمایش (مثلاً «آفلاین (Vosk)»).
  String get engineName;
}

/// تشخیص گفتار با سرویس خود گوشی (رفتار قبلی).
class OnlineVoiceInput implements VoiceInput {
  OnlineVoiceInput();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;

  @override
  String get engineName => 'سرویس گوشی';

  @override
  bool get isReady => _ready;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    _ready = await _speech.initialize(
      onStatus: (status) => onStatus('وضعیت تشخیص صدا: $status'),
      onError: (error) => onError('خطای تشخیص صدا: ${error.errorMsg}'),
    );
    return _ready;
  }

  @override
  Future<void> start({
    required void Function(String partialText) onPartial,
    required void Function(double level) onSoundLevel,
    required void Function(String finalText) onResult,
  }) async {
    _listening = true;
    await _speech.listen(
      onSoundLevelChange: (level) => onSoundLevel(level),
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        } else if (result.recognizedWords.isNotEmpty) {
          onPartial(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'fa_IR',
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 4),
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        // false یعنی از سرویس تشخیص گفتار خود گوشی استفاده شود؛
        // ممکن است آنلاین باشد، اما API پولی لازم ندارد.
        onDevice: false,
        autoPunctuation: true,
        enableHapticFeedback: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _speech.cancel();
  }
}

/// تشخیص گفتار آفلاین با Vosk.
///
/// نیازمند فایل مدل فارسی (`scripts/download_vosk_model.sh`).
/// وقتی مدل موجود نباشد، [initialize] با false برمی‌گردد و لایهٔ بالاتر
/// به [OnlineVoiceInput] سقوط می‌کند.
class OfflineVoskVoiceInput implements VoiceInput {
  OfflineVoskVoiceInput({required this.modelPath});

  final String modelPath;

  VoskFlutterPlugin? _vosk;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  StreamSubscription<String>? _resultSub;
  StreamSubscription<String>? _partialSub;
  bool _ready = false;
  bool _listening = false;

  @override
  String get engineName => 'آفلاین (Vosk)';

  @override
  bool get isReady => _ready;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    try {
      onStatus('در حال بارگذاری مدل آفلاین...');
      final vosk = VoskFlutterPlugin.instance();

      // مسیر مدل را آماده کن: assets یا zip در دیسک → پوشهٔ استخراج‌شده.
      final modelDir = await _resolveModelDirectory(modelPath);
      final model = await vosk.createModel(modelDir);
      _recognizer = await vosk.createRecognizer(model: model, sampleRate: 16000);
      _speechService = await vosk.initSpeechService(_recognizer!);
      _vosk = vosk;
      _ready = true;
      return true;
    } catch (e) {
      _ready = false;
      onError('مدل آفلاین در دسترس نیست: $e');
      return false;
    }
  }

  /// تبدیل مسیر مدل به پوشهٔ آماده برای [VoskFlutterPlugin.createModel].
  ///
  /// - اگر مسیر با `assets/` شروع شود → با [ModelLoader] استخراج می‌شود.
  /// - اگر فایل zip روی دیسک باشد → خودمان استخراج می‌کنیم.
  /// - در غیر این صورت فرض می‌کنیم پوشهٔ از قبل استخراج‌شده است.
  Future<String> _resolveModelDirectory(String path) async {
    if (path.startsWith('assets/')) {
      return ModelLoader().loadFromAssets(path);
    }
    final file = File(path);
    if (file.existsSync() && path.toLowerCase().endsWith('.zip')) {
      return _extractZipToDocuments(file);
    }
    return path;
  }

  Future<String> _extractZipToDocuments(File zipFile) async {
    final docs = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docs.path, 'vosk', 'models'));
    await targetDir.create(recursive: true);

    // اگر از قبل استخراج شده، دوباره استخراج نکن.
    final expectedDir = Directory(
      p.join(targetDir.path, kVoskModelDirName),
    );
    if (expectedDir.existsSync()) return expectedDir.path;

    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final outPath = p.join(targetDir.path, entry.name);
      if (entry.isFile) {
        final outFile = File(outPath);
        outFile.parent.createSync(recursive: true);
        outFile.writeAsBytesSync(entry.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }
    return expectedDir.path;
  }

  @override
  Future<void> start({
    required void Function(String partialText) onPartial,
    required void Function(double level) onSoundLevel,
    required void Function(String finalText) onResult,
  }) async {
    final service = _speechService;
    if (service == null) return;

    _listening = true;
    // نتایج جزئی
    _partialSub ??= service.onPartial().listen((raw) {
      final text = _parseVoskText(raw, partial: true);
      if (text.isNotEmpty) onPartial(text);
    });
    // نتایج نهایی
    _resultSub ??= service.onResult().listen((raw) {
      final text = _parseVoskText(raw, partial: false);
      if (text.isNotEmpty) onResult(text);
    });
    // سطح صدا در Vosk گزارش نمی‌شود؛ مقدار میانی ثابت برای UI.
    onSoundLevel(0.3);

    await service.start();
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _speechService?.stop();
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _speechService?.cancel();
  }

  /// استخراج متن از JSON خروجی Vosk:
  /// نهایی: {"text": "..."} / جزئی: {"partial": "..."}
  String _parseVoskText(String raw, {required bool partial}) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final key = partial ? 'partial' : 'text';
      return (map[key] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }
}

/// ساخت [VoiceInput] مناسب بر اساس feature flag و موجود بودن مدل.
///
/// - اگر `ENABLE_OFFLINE_SPEECH=true` و مدل Vosk موجود باشد → آفلاین
/// - در غیر این صورت → سرویس گوشی (آنلاین)
class VoiceInputFactory {
  const VoiceInputFactory._();

  /// [forceOffline] فقط برای تست است؛ در اجرای واقعی از [FeatureFlags] خوانده می‌شود.
  static Future<VoiceInput> create({
    VoskModelLocator? locator,
    bool? forceOffline,
  }) async {
    final useOffline = forceOffline ?? FeatureFlags.enableOfflineSpeech;
    if (useOffline) {
      final modelPath = await (locator ?? VoskModelLocator()).find();
      if (modelPath != null) {
        return OfflineVoskVoiceInput(modelPath: modelPath);
      }
    }
    return OnlineVoiceInput();
  }

  /// آیا حالت آفلاین فعال و مدل موجود است؟ (برای نمایش وضعیت)
  static Future<bool> isOfflineAvailable({
    VoskModelLocator? locator,
    bool? forceOffline,
  }) async {
    final useOffline = forceOffline ?? FeatureFlags.enableOfflineSpeech;
    if (!useOffline) return false;
    final modelPath = await (locator ?? VoskModelLocator()).find();
    return modelPath != null;
  }
}
