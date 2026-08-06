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

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _enabled = true;
  AssistantVoiceGender _gender = AssistantVoiceGender.feminine;
  List<Map<String, String>> _persianVoices = [];

  bool get enabled => _enabled;
  AssistantVoiceGender get gender => _gender;
  List<Map<String, String>> get persianVoices => List.unmodifiable(_persianVoices);

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    final savedGender = prefs.getString(_genderKey);
    _gender = AssistantVoiceGender.values.firstWhere(
      (g) => g.name == savedGender,
      orElse: () => AssistantVoiceGender.feminine,
    );

    await _tts.setLanguage('fa-IR');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);

    await _loadPersianVoices();
    await _applyPreferredVoice();

    _initialized = true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) await stop();
  }

  Future<void> setGender(AssistantVoiceGender gender) async {
    _gender = gender;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender.name);
    await _applyPreferredVoice();
  }

  Future<void> speak(String text, {bool force = false}) async {
    await initialize();
    if (!_enabled && !force) return;

    final cleanText = _prepareForSpeech(text);
    if (cleanText.trim().isEmpty) return;

    await _tts.stop();
    await _tts.speak(cleanText);
  }

  Future<void> stop() => _tts.stop();

  Future<String> testVoice() async {
    final sample = _gender == AssistantVoiceGender.feminine
        ? 'سلام، من دستیار فارسی شما هستم. با صدای زن آماده کمک به برنامه‌ریزی و حسابداری روزانه‌ات هستم.'
        : 'سلام، من دستیار فارسی شما هستم. با صدای مرد آماده کمک به برنامه‌ریزی و حسابداری روزانه‌ات هستم.';
    await speak(sample, force: true);
    return sample;
  }

  Future<void> _loadPersianVoices() async {
    try {
      final voices = await _tts.getVoices;
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
    await _tts.setLanguage('fa-IR');

    final preferred = _pickVoice(_gender);
    if (preferred == null) return;

    try {
      await _tts.setVoice(preferred);
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

  String _prepareForSpeech(String text) {
    return PersianFormat.digits(text)
        .replaceAll('•', '')
        .replaceAll('—', '، ')
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
