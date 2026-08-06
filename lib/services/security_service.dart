import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SecurityService extends ChangeNotifier {
  SecurityService._();

  static final SecurityService instance = SecurityService._();

  static const _enabledKey = 'smart_day_planner.security.pin_enabled';
  static const _saltKey = 'smart_day_planner.security.pin_salt';
  static const _hashKey = 'smart_day_planner.security.pin_hash';

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

    final ok = _hashPin(pin.trim(), _salt) == _hash;
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

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt|$pin|smart_day_planner')).toString();
  }

  String _randomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
