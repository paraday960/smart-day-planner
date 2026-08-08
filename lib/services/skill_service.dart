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
  static const _streakKey = 'skill_streak_v1';
  static const _lastDateKey = 'skill_last_learned_date_v1';
  static const _achievementsKey = 'skill_achievements_v1';

  int _score = 0;
  int _learnedCount = 0;
  int _streak = 0;
  String? _lastLearnedDate; // yyyy-MM-dd
  final Set<String> _achievements = {};
  final List<Map<String, dynamic>> _history = [];
  bool _loaded = false;

  int get score => _score;
  int get learnedCount => _learnedCount;
  int get level => _score ~/ 100 + 1;
  int get progressToNextLevel => _score % 100; // 0..99
  double get progressFraction => progressToNextLevel / 100.0;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
  int get streak => _streak;
  Set<String> get achievements => Set.unmodifiable(_achievements);
  String? get lastLearnedDate => _lastLearnedDate;

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
      _streak = prefs.getInt(_streakKey) ?? 0;
      _lastLearnedDate = prefs.getString(_lastDateKey);
      final achRaw = prefs.getString(_achievementsKey);
      if (achRaw != null && achRaw.isNotEmpty) {
        final decodedAch = jsonDecode(achRaw);
        if (decodedAch is List) {
          _achievements.clear();
          for (final e in decodedAch) _achievements.add(e.toString());
        }
      }
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
      await prefs.setInt(_streakKey, _streak);
      if (_lastLearnedDate != null) await prefs.setString(_lastDateKey, _lastLearnedDate!);
      await prefs.setString(_achievementsKey, jsonEncode(_achievements.toList()));
      await prefs.setString(_historyKey, jsonEncode(_history));
    } catch (_) {}
  }

  Future<void> addPoints(int points, String reason) async {
    await load();
    _score += points;
    _learnedCount++;
    _updateStreak();
    _checkAchievements();
    final entry = {
      'points': points,
      'reason': reason,
      'at': DateTime.now().toIso8601String(),
      'score': _score,
      'level': level,
      'streak': _streak,
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

  void _updateStreak() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastLearnedDate == today) return; // امروز قبلاً حساب شده
    if (_lastLearnedDate == null) {
      _streak = 1;
    } else {
      try {
        final last = DateTime.parse(_lastLearnedDate!);
        final now = DateTime.parse(today);
        final diff = now.difference(last).inDays;
        if (diff == 1) {
          _streak++;
        } else if (diff > 1) {
          _streak = 1; // استریک شکست، دوباره از ۱
        }
      } catch (_) {
        _streak = 1;
      }
    }
    _lastLearnedDate = today;
  }

  void _checkAchievements() {
    final newOnes = <String>[];
    if (_score >= 10 && !_achievements.contains('اولین_یادگیری')) newOnes.add('اولین_یادگیری');
    if (_learnedCount >= 5 && !_achievements.contains('پنج_یادگیری')) newOnes.add('پنج_یادگیری');
    if (_score >= 100 && !_achievements.contains('سطح_۲')) newOnes.add('سطح_۲');
    if (_score >= 500 && !_achievements.contains('سطح_۶')) newOnes.add('سطح_۶');
    if (_score >= 1000 && !_achievements.contains('استاد')) newOnes.add('استاد');
    if (_streak >= 3 && !_achievements.contains('استریک_۳')) newOnes.add('استریک_۳');
    if (_streak >= 7 && !_achievements.contains('استریک_۷')) newOnes.add('استریک_۷');
    if (newOnes.isNotEmpty) {
      _achievements.addAll(newOnes);
      // امتیاز جایزه برای هر اچیومنت
      // (بدون بازگشت بی‌نهایت — فقط یک بار)
    }
  }

  bool hasAchievement(String id) => _achievements.contains(id);

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
    _streak = 0;
    _lastLearnedDate = null;
    _achievements.clear();
    _history.clear();
    _lastReward = null;
    await _save();
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _score = 0;
    _learnedCount = 0;
    _streak = 0;
    _lastLearnedDate = null;
    _achievements.clear();
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
