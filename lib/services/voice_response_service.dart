import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/services/voice_response_port.dart';
import '../models/assistant_voice_gender.dart';
export '../models/assistant_voice_gender.dart';
import '../utils/persian_format.dart';

class VoiceResponseService implements VoiceResponsePort {
  VoiceResponseService._();

  static final VoiceResponseService instance = VoiceResponseService._();
  static const _enabledKey = 'smart_day_planner.voice_response.enabled';
  static const _genderKey = 'smart_day_planner.voice_response.gender';

  FlutterTts? _tts;
  FlutterTts get _ttsInstance {
    _tts ??= FlutterTts();
    return _tts!;
  }

  bool _initialized = false;
  bool _enabled = true;
  AssistantVoiceGender _gender = AssistantVoiceGender.feminine;
  List<Map<String, String>> _persianVoices = [];

  @override
  bool get enabled => _enabled;
  @override
  AssistantVoiceGender get gender => _gender;
  List<Map<String, String>> get persianVoices => List.unmodifiable(_persianVoices);

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    final savedGender = prefs.getString(_genderKey);
    _gender = AssistantVoiceGender.values.firstWhere(
      (g) => g.name == savedGender,
      orElse: () => AssistantVoiceGender.feminine,
    );

    try {
      await _ttsInstance.setLanguage('fa-IR');
    } catch (_) {
      // بعضی موتورهای گفتار فارسی را با کد fa_IR می‌پذیرند.
      try {
        await _ttsInstance.setLanguage('fa_IR');
      } catch (_) {}
    }
    await _ttsInstance.setSpeechRate(0.46);
    await _ttsInstance.setPitch(1.0);
    await _ttsInstance.setVolume(1.0);
    await _ttsInstance.awaitSpeakCompletion(false);

    await _loadPersianVoices();
    await _applyPreferredVoice();

    _initialized = true;
  }

  @override
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) await stop();
  }

  @override
  Future<void> setGender(AssistantVoiceGender gender) async {
    _gender = gender;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender.name);
    await _applyPreferredVoice();
  }

  @override
  Future<void> speak(String text, {bool force = false}) async {
    await initialize();
    if (!_enabled && !force) return;

    final cleanText = _prepareForSpeech(text);
    if (cleanText.trim().isEmpty) return;

    try {
      await _ttsInstance.stop();
    } catch (_) {}
    try {
      await _ttsInstance.speak(cleanText);
    } catch (_) {
      // اگر زبان fa-IR تنظیم نشده بود، یک بار بدون تنظیم زبان تلاش می‌کنیم.
      try {
        await _ttsInstance.setLanguage('fa-IR');
        await _ttsInstance.speak(cleanText);
      } catch (_) {}
    }
  }

  @override
  Future<void> stop() async {
    if (_tts == null) return;
    await _tts!.stop();
  }

  @override
  Future<String> testVoice() async {
    final sample = _gender == AssistantVoiceGender.feminine
        ? 'سلام، من دستیار فارسی شما هستم. با صدای زن آماده کمک به برنامه‌ریزی و حسابداری روزانه‌ات هستم.'
        : 'سلام، من دستیار فارسی شما هستم. با صدای مرد آماده کمک به برنامه‌ریزی و حسابداری روزانه‌ات هستم.';
    await speak(sample, force: true);
    return sample;
  }

  Future<void> _loadPersianVoices() async {
    try {
      final voices = await _ttsInstance.getVoices;
      if (voices is! List) return;

      _persianVoices = voices
          .whereType<Map>()
          .map((voice) => voice.map((key, value) => MapEntry(key.toString(), value.toString())))
          .where((voice) {
            final locale = (voice['locale'] ?? voice['language'] ?? '').toLowerCase();
            final name = (voice['name'] ?? '').toLowerCase();
            return locale.contains('fa') || locale.contains('ir') || name.contains('persian') || name.contains('farsi') || name.contains('fa-ir');
          })
          .toList();
    } catch (_) {
      _persianVoices = [];
    }
  }

  Future<void> _applyPreferredVoice() async {
    await _ttsInstance.setLanguage('fa-IR');

    final preferred = _pickVoice(_gender);
    if (preferred == null) return;

    try {
      await _ttsInstance.setVoice(preferred);
    } catch (_) {
      // اگر موتور گفتار گوشی setVoice را قبول نکرد، همان زبان فارسی سیستم استفاده می‌شود.
    }
  }

  Map<String, String>? _pickVoice(AssistantVoiceGender gender) {
    if (_persianVoices.isEmpty) return null;

    final feminineKeywords = ['female', 'woman', 'zira', 'sara', 'roya', 'dilara', 'feminine', 'زن'];
    final masculineKeywords = ['male', 'man', 'farid', 'omid', 'dariush', 'masculine', 'مرد'];
    final keywords = gender == AssistantVoiceGender.feminine ? feminineKeywords : masculineKeywords;

    for (final voice in _persianVoices) {
      final name = '${voice['name'] ?? ''} ${voice['locale'] ?? ''}'.toLowerCase();
      if (keywords.any(name.contains)) return voice;
    }

    // اگر جنسیت مشخص نبود، برای زن اولین صدا و برای مرد دومین صدا را انتخاب می‌کنیم.
    if (gender == AssistantVoiceGender.masculine && _persianVoices.length > 1) {
      return _persianVoices[1];
    }
    return _persianVoices.first;
  }

  /// آماده‌سازی متن برای گفتار: ایموجی‌ها و کاراکترهای نامربوط حذف می‌شوند
  /// تا موتور گفتار فارسی به‌درستی و بدون «ماینس‌ماینس» بخواند. عمومی است تا
  /// قابل تست باشد.
  @visibleForTesting
  String prepareForSpeech(String text) {
    return _prepareForSpeech(text);
  }

  String _prepareForSpeech(String text) {
    // حذف ایموجی‌ها و نمادهای خاص که موتور گفتار فارسی نمی‌تواند بخواند و
    // باعث «ماینس‌ماینس»/تلفظ انگلیسی می‌شود.
    final noEmoji = text.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2B00}-\u{2BFF}\u{1F600}-\u{1F64F}\u{2190}-\u{21FF}\u{2B50}\u{2764}\u{2705}\u{2728}]',
        unicode: true,
      ),
      '',
    );
    return PersianFormat.digits(noEmoji)
        .replaceAll('•', '')
        .replaceAll('—', '، ')
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceAll(RegExp(r'[«»"]'), '')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
