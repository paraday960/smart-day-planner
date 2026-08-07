import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService extends ChangeNotifier {
  SecurityService._();

  static final SecurityService instance = SecurityService._();

  static const _enabledKey = 'smart_day_planner.security.pin_enabled';
  static const _saltKey = 'smart_day_planner.security.pin_salt';
  static const _hashKey = 'smart_day_planner.security.pin_hash';

  /// تعداد تکرار PBKDF2-HMAC-SHA256 برای استخراج هش PIN.
  /// عدد بالا = هزینهٔ brute-force روی PIN ۴رقمی بسیار زیاد می‌شود.
  static const int _pbkdf2Iterations = 200000;
  static const int _pbkdf2KeyLength = 32;

  bool _loaded = false;
  bool _pinEnabled = false;
  bool _unlocked = false;
  String _salt = '';
  String _hash = '';

  bool get loaded => _loaded;
  bool get pinEnabled => _pinEnabled;
  bool get unlocked => !_pinEnabled || _unlocked;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pinEnabled = prefs.getBool(_enabledKey) ?? false;
    _salt = prefs.getString(_saltKey) ?? '';
    _hash = prefs.getString(_hashKey) ?? '';
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
    _hash = _hashPin(normalized, _salt);
    _pinEnabled = true;
    _unlocked = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_saltKey, _salt);
    await prefs.setString(_hashKey, _hash);
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    if (!_pinEnabled) {
      _unlocked = true;
      notifyListeners();
      return true;
    }

    var ok = _hashPin(pin.trim(), _salt) == _hash;

    // مهاجرت از هش قدیمی (SHA-256 خام، ۶۴ کاراکتر hex): اگر با هش جدید جور
    // نشد و مقدار ذخیره‌شده قالب قدیمی دارد، با الگوریتم قدیمی بررسی کن؛
    // در صورت تأیید، بلافاصله هش امن جدید جایگزین و ذخیره می‌شود تا دفعهٔ بعد
    // از PBKDF2 استفاده شود. به این ترتیب کاربرانی که قبلاً PIN گذاشته‌اند
    // از دستگاه قفل نمی‌شوند.
    if (!ok && _isLegacyHash(_hash)) {
      ok = _hashPinLegacy(pin.trim(), _salt) == _hash;
      if (ok) {
        _hash = _hashPin(pin.trim(), _salt);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_hashKey, _hash);
      }
    }

    if (ok) {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_saltKey);
    await prefs.remove(_hashKey);
    notifyListeners();
  }

  /// هش PIN با PBKDF2-HMAC-SHA256 + نمک اختصاصی (به‌جای SHA-256 خام قدیمی).
  /// خروجی base64 از کلید مشتق‌شدهٔ ۳۲ بایتی است.
  String _hashPin(String pin, String salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(utf8.encode(salt)),
        _pbkdf2Iterations,
        _pbkdf2KeyLength,
      ));
    final derived = derivator.process(utf8.encode('$salt|$pin|smart_day_planner'))
        as Uint8List;
    return base64Encode(derived);
  }

  /// هش قدیمی (SHA-256 خام) — فقط برای مهاجرت کاربرانی که قبلاً PIN ست کرده‌اند.
  String _hashPinLegacy(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt|$pin|smart_day_planner')).toString();
  }

  /// تشخیص هش قدیمی: مقدار ذخیره‌شده دقیقاً ۶۴ کاراکتر hex باشد (SHA-256).
  bool _isLegacyHash(String stored) {
    if (stored.length != 64) return false;
    for (var i = 0; i < stored.length; i++) {
      final c = stored.codeUnitAt(i);
      final isDigit = c >= 48 && c <= 57;
      final isLowerHex = c >= 97 && c <= 102;
      if (!isDigit && !isLowerHex) return false;
    }
    return true;
  }

  String _randomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
