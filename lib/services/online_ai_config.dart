import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات هوش مصنوعی آنلاین.
///
/// کلید رایگان را به‌صورت محلی روی دستگاه (SharedPreferences) نگه می‌دارد
/// تا کاربر فقط یک بار در تنظیمات وارد کند و دفعهٔ بعد نیازی نباشد.
///
/// هیچ کلید پیش‌فرضی داخل برنامه تعبیه نشده است؛ کاربر کلید رایگان خودش را
/// وارد می‌کند یا می‌تواند هنگام ساخت با `--dart-define=ONLINE_AI_API_KEY=...`
/// آن را قفل کند. بدون کلید، دستیار خودکار به موتور قانون‌محور برمی‌گردد.
class OnlineAiConfig {
  OnlineAiConfig._();
  static final OnlineAiConfig instance = OnlineAiConfig._();

  static const String _keyPref = 'online_ai_api_key';
  static const String _providerPref = 'online_ai_provider';

  /// شناسهٔ سرویس‌های پشتیبانی‌شده.
  static const String providerGemini = 'gemini';
  static const String providerGroq = 'groq';
  static const String providerDeepseek = 'deepseek';
  static const String providerGapgpt = 'gapgpt';
  static const String providerMistral = 'mistral';

  String _apiKey = '';
  String _provider = providerGemini;
  bool _loaded = false;

  /// برای اطلاع‌رسانی به UI هنگام تغییر تنظیمات.
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  String get apiKey => _apiKey;
  String get provider => _provider;
  bool get hasKey => _apiKey.isNotEmpty;
  bool get isLoaded => _loaded;

  /// بارگذاری از SharedPreferences.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_keyPref) ?? '';
      _provider = prefs.getString(_providerPref) ?? providerGemini;
    } catch (_) {
      // بدون دسترسی به prefs هم برنامه به‌درستی کار می‌کند.
    }
    _loaded = true;
    version.value++;
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  /// ذخیرهٔ کلید و (اختیاری) تغییر سرویس.
  Future<void> set(String apiKey, {String? provider}) async {
    await _ensureLoaded();
    _apiKey = apiKey.trim();
    if (provider != null) _provider = provider;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPref, _apiKey);
      await prefs.setString(_providerPref, _provider);
    } catch (_) {}
    version.value++;
  }

  /// پاک کردن کلید (بازگشت به حالت بدون هوش آنلاین).
  Future<void> clear() async {
    await _ensureLoaded();
    _apiKey = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPref);
    } catch (_) {}
    version.value++;
  }

  /// بازنشانی حالت درون‌حافظه‌ای (برای تست).
  @visibleForTesting
  void reset() {
    _apiKey = '';
    _provider = providerGemini;
    _loaded = false;
  }
}
