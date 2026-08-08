import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات هوش مصنوعی آنلاین.
///
/// کلید رایگان را به‌صورت امن روی دستگاه نگه می‌دارد (Keystore اندروید /
/// Keychain آی‌اواس از طریق `flutter_secure_storage`) تا کاربر فقط یک بار
/// در تنظیمات وارد کند و دفعهٔ بعد نیازی نباشد.
///
/// اگر ذخیرهٔ امن در دسترس نباشد (مثلاً در تست یا دستگاه‌های قدیمی)،
/// خودکار به SharedPreferences برمی‌گردد و هنگام در دسترس شدن، دادهٔ
/// قدیمی به حافظهٔ امن مهاجرت داده می‌شود.
///
/// هیچ کلید پیش‌فرضی داخل برنامه تعبیه نشده است؛ کاربر کلید رایگان خودش را
/// وارد می‌کند یا می‌تواند هنگام ساخت با `--dart-define=ONLINE_AI_API_KEY=...`
/// آن را قفل کند. بدون کلید، دستیار خودکار به موتور قانون‌محور برمی‌گردد.
class OnlineAiConfig {
  OnlineAiConfig._();
  static final OnlineAiConfig instance = OnlineAiConfig._();

  static const String _keyPref = 'online_ai_api_key';
  static const String _providerPref = 'online_ai_provider';

  /// کلید قدیمی‌ای که قبلاً (پیش از نسخهٔ امن) در SharedPreferences
  /// ذخیره می‌شد — برای مهاجرت یک‌باره به حافظهٔ امن.
  static const String _legacyKeyPref = 'online_ai_api_key_legacy_marker';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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

  /// بارگذاری از حافظهٔ امن (با fallback به SharedPreferences و مهاجرت).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _provider = prefs.getString(_providerPref) ?? providerGemini;

      // ۱) اول حافظهٔ امن
      var key = await _secureRead(_keyPref);
      // ۲) اگر نبود، SharedPreferences قدیمی → مهاجرت به حافظهٔ امن
      if (key == null) {
        final legacy = prefs.getString(_keyPref);
        if (legacy != null && legacy.isNotEmpty) {
          key = legacy;
          await _secureWrite(_keyPref, legacy);
          await prefs.remove(_keyPref);
          await prefs.setBool(_legacyKeyPref, true);
        }
      }
      _apiKey = key ?? '';
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
      await _secureWrite(_keyPref, _apiKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_providerPref, _provider);
      // کلید قدیمی (در صورت وجود) پاک شود.
      await prefs.remove(_keyPref);
    } catch (_) {}
    version.value++;
  }

  /// پاک کردن کلید (بازگشت به حالت بدون هوش آنلاین).
  Future<void> clear() async {
    await _ensureLoaded();
    _apiKey = '';
    try {
      await _secureDelete(_keyPref);
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

  // ── لایهٔ ذخیرهٔ امن با fallback ──────────────────────────────
  // در تست‌ها و پلتفرم‌های بدون Keystore، فراخوانی امن خطا می‌دهد؛
  // در آن صورت به SharedPreferences برمی‌گردیم تا هیچ وقت شکست نخوریم.

  Future<String?> _secureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> _secureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  Future<void> _secureDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // در حالت fallback چیزی برای پاک کردن نیست.
    }
  }
}
