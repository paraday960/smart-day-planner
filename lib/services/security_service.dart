import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس قفل PIN با امنیت ارتقایافته.
///
/// **اصلاح امنیتی (2026-08-07):**
/// قبلاً PIN با SHA-256 خام هش می‌شد: `sha256(salt|pin|...)`
/// PIN چهاررقمی + SHA-256 سریع = Brute-force بسیار آسان (10k ترکیب).
/// الان:
/// - استخراج هش با PBKDF2-HMAC-SHA256 با 100k تکرار و نمک تصادفی
/// - مقایسه در زمان ثابت (constant-time) برای جلوگیری از timing attack
/// - مهاجرت خودکار از فرمت قدیمی (SHA256 hex) به فرمت جدید (PBKDF2 base64)
///   هنگام verify موفق.
/// - اگر هش قدیمی بود و درست بود، به‌صورت خودکار ارتقا می‌یابد.
class SecurityService extends ChangeNotifier {
  SecurityService._();

  static final SecurityService instance = SecurityService._();

  static const _enabledKey = 'smart_day_planner.security.pin_enabled';
  static const _saltKey = 'smart_day_planner.security.pin_salt';
  static const _hashKey = 'smart_day_planner.security.pin_hash';
  static const _iterationsKey = 'smart_day_planner.security.pin_iterations';

  /// تعداد تکرار PBKDF2 برای PIN. 100k تعادل خوبی بین امنیت و سرعت روی
  /// گوشی‌های میان‌رده است. بکاپ از 200k استفاده می‌کند چون کمتر فراخوانی می‌شود.
  static const int _pbkdf2Iterations = 100000;
  static const int _pbkdf2KeyLength = 32;

  bool _loaded = false;
  bool _pinEnabled = false;
  bool _unlocked = false;
  String _salt = '';
  String _hash = '';
  int _iterations = _pbkdf2Iterations;

  bool get loaded => _loaded;
  bool get pinEnabled => _pinEnabled;
  bool get unlocked => !_pinEnabled || _unlocked;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pinEnabled = prefs.getBool(_enabledKey) ?? false;
    _salt = prefs.getString(_saltKey) ?? '';
    _hash = prefs.getString(_hashKey) ?? '';
    _iterations = prefs.getInt(_iterationsKey) ?? _pbkdf2Iterations;
    _unlocked = !_pinEnabled;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.length < 4) {
      throw ArgumentError('رمز باید حداقل ۴ رقم باشد.');
    }

    _salt = _randomSalt();
    _iterations = _pbkdf2Iterations;
    _hash = _hashPinPbKdf2(normalized, _salt, _iterations);
    _pinEnabled = true;
    _unlocked = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_saltKey, _salt);
    await prefs.setString(_hashKey, _hash);
    await prefs.setInt(_iterationsKey, _iterations);
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    if (!_pinEnabled) {
      _unlocked = true;
      notifyListeners();
      return true;
    }

    final trimmed = pin.trim();
    if (_salt.isEmpty || _hash.isEmpty) return false;

    bool ok;
    bool isLegacy = _isLegacyHash(_hash);

    if (isLegacy) {
      ok = _constantTimeEquals(_legacyHashPin(trimmed, _salt), _hash);
    } else {
      final computed = _hashPinPbKdf2(trimmed, _salt, _iterations);
      ok = _constantTimeEquals(computed, _hash);
    }

    if (ok) {
      // مهاجرت خودکار: اگر هش قدیمی بود، به فرمت امن جدید ارتقا بده
      if (isLegacy) {
        try {
          final newSalt = _randomSalt();
          final newHash = _hashPinPbKdf2(trimmed, newSalt, _pbkdf2Iterations);
          _salt = newSalt;
          _hash = newHash;
          _iterations = _pbkdf2Iterations;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_saltKey, _salt);
          await prefs.setString(_hashKey, _hash);
          await prefs.setInt(_iterationsKey, _iterations);
        } catch (_) {
          // مهاجرت اختیاری است؛ حتی اگر شکست بخورد، verify موفق بوده
        }
      }
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  Future<void> lock() async {
    if (!_pinEnabled) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<void> disablePin() async {
    _pinEnabled = false;
    _unlocked = true;
    _salt = '';
    _hash = '';
    _iterations = _pbkdf2Iterations;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_saltKey);
    await prefs.remove(_hashKey);
    await prefs.remove(_iterationsKey);
    notifyListeners();
  }

  /// هش امن جدید با PBKDF2-HMAC-SHA256
  String _hashPinPbKdf2(String pin, String salt, int iterations) {
    final saltBytes = _decodeSalt(salt);
    final keyBytes = _deriveKeyBytes(pin, saltBytes, iterations);
    return base64UrlEncode(keyBytes);
  }

  /// هش قدیمی ناامن (برای مهاجرت) - SHA256 خام
  String _legacyHashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt|$pin|smart_day_planner')).toString();
  }

  bool _isLegacyHash(String hash) {
    // هش SHA256 hex = 64 کاراکتر هگزادسیمال
    if (hash.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      return true;
    }
    return false;
  }

  Uint8List _deriveKeyBytes(String pin, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, _pbkdf2KeyLength));
    return derivator.process(utf8.encode(pin)) as Uint8List;
  }

  Uint8List _decodeSalt(String salt) {
    try {
      return base64Url.decode(salt);
    } catch (_) {
      try {
        return base64Decode(salt);
      } catch (_) {
        // سازگاری با نمک‌های قدیمی که ممکن است base64 نباشند
        return Uint8List.fromList(utf8.encode(salt));
      }
    }
  }

  /// مقایسه زمان-ثابت برای جلوگیری از timing attack
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  String _randomSalt({int length = 24}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
