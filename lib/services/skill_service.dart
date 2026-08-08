import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سرویس امتیاز مهارت هوش محلی — هر بار که هوش محلی چیزی یاد می‌گیرد، امتیاز می‌دهد.
///
/// سطوح: هر ۱۰۰ امتیاز = ۱ لِوِل
/// - یادگیری جواب جدید از آنلاین: +۱۰
/// - یادگیری سناریو جدید: +۱۵
/// - استفاده مجدد از سناریوی یادگرفته‌شده: +۵
/// - بازخورد مثبت کاربر: +۲
class SkillService extends ChangeNotifier {
  SkillService._();
  static final SkillService instance = SkillService._();

  static const _scoreKey = 'skill_score_v1';
  static const _historyKey = 'skill_history_v1';
  static const _countKey = 'skill_learned_count_v1';

  int _score = 0;
  int _learnedCount = 0;
  final List<Map<String, dynamic>> _history = [];
  bool _loaded = false;

  int get score => _score;
  int get learnedCount => _learnedCount;
  int get level => _score ~/ 100 + 1;
  int get progressToNextLevel => _score % 100; // 0..99
  double get progressFraction => progressToNextLevel / 100.0;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  /// آخرین یادگیری برای نمایش انیمیشن +امتیاز
  Map<String, dynamic>? _lastReward;
  Map<String, dynamic>? get lastReward => _lastReward;

  String get levelLabel {
    if (level >= 10) return 'استاد ⭐';
    if (level >= 7) return 'حرفه‌ای 🔥';
    if (level >= 5) return 'ماهر 💎';
    if (level >= 3) return 'در حال رشد 🌱';
    return 'تازه‌کار 🌟';
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _score = prefs.getInt(_scoreKey) ?? 0;
      _learnedCount = prefs.getInt(_countKey) ?? 0;
      final raw = prefs.getString(_historyKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _history.clear();
          for (final e in decoded) {
            if (e is Map) _history.add(Map<String, dynamic>.from(e));
          }
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_scoreKey, _score);
      await prefs.setInt(_countKey, _learnedCount);
      await prefs.setString(_historyKey, jsonEncode(_history));
    } catch (_) {}
  }

  Future<void> addPoints(int points, String reason) async {
    await load();
    _score += points;
    _learnedCount++;
    final entry = {
      'points': points,
      'reason': reason,
      'at': DateTime.now().toIso8601String(),
      'score': _score,
      'level': level,
    };
    _history.add(entry);
    _lastReward = entry;
    if (_history.length > 50) _history.removeAt(0);
    await _save();
    notifyListeners();
    // پاک کردن آخرین پاداش بعد از 4 ثانیه تا انیمیشن محو شود
    Future.delayed(const Duration(seconds: 4), () {
      _lastReward = null;
      notifyListeners();
    });
  }

  Future<void> addForLocalAnswer({String? question}) async {
    final shortQ = (question ?? '').trim();
    final reason = shortQ.length > 30 ? '${shortQ.substring(0, 30)}…' : shortQ;
    await addPoints(10, reason.isEmpty ? 'یادگیری جواب محلی' : 'یادگیری: $reason');
  }

  Future<void> addForScenario({String? fingerprint}) async {
    await addPoints(15, 'یادگیری سناریو${fingerprint != null ? ' $fingerprint' : ''}');
  }

  Future<void> addForScenarioReuse() async {
    await addPoints(5, 'استفاده از سناریوی یادگرفته');
  }

  Future<void> addForFeedback() async {
    await addPoints(2, 'بازخورد مثبت');
  }

  Future<void> clear() async {
    _score = 0;
    _learnedCount = 0;
    _history.clear();
    _lastReward = null;
    await _save();
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _score = 0;
    _learnedCount = 0;
    _history.clear();
    _lastReward = null;
    _loaded = false;
  }

  @override
  void dispose() {
    // Singleton — نباید واقعاً dispose شود، چون بین تست‌ها و ProviderScopeهای مختلف
    // دوباره استفاده می‌شود. اگر super.dispose() صدا زده شود، ChangeNotifier
    // علامت disposed می‌خورد و تست بعدی با خطای "used after being disposed" فیل می‌شود.
    // پس برای singleton هیچ کاری نمی‌کنیم (فقط listenerها باقی می‌مانند که در تست مشکلی نیست).
  }
}
