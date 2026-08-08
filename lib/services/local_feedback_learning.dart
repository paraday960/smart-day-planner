import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// آمار بازخورد برای یک intent.
class IntentFeedbackStats {
  IntentFeedbackStats({
    this.success = 0,
    this.failure = 0,
    this.ambiguity = 0,
    this.score = 0,
  });

  int success;
  int failure;
  int ambiguity;
  double score;

  int get total => success + failure;
  double get successRate => total == 0 ? 0.5 : success / total;

  Map<String, dynamic> toJson() => {
        'success': success,
        'failure': failure,
        'ambiguity': ambiguity,
        'score': score,
      };

  factory IntentFeedbackStats.fromJson(Map<String, dynamic> json) =>
      IntentFeedbackStats(
        success: (json['success'] as num?)?.toInt() ?? 0,
        failure: (json['failure'] as num?)?.toInt() ?? 0,
        ambiguity: (json['ambiguity'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

/// یادگیری سبک از بازخورد کاربر روی پاسخ‌های محلی — بدون نیاز به آنلاین.
class IntentFeedbackStore {
  IntentFeedbackStore({
    this.decay = 0.98,
    int? seed,
    this.prefs,
    this.storageKey = _defaultKey,
  }) : _random = Random(seed);

  static const String _defaultKey = 'intent_feedback_v1';

  final double decay;
  final Random _random;
  final Map<String, IntentFeedbackStats> _stats = {};
  final SharedPreferences? prefs;
  final String storageKey;
  bool _loaded = false;
  bool _dirty = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final raw = p.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _stats.clear();
          for (final e in decoded.entries) {
            final v = e.value;
            if (v is Map<String, dynamic>) {
              _stats[e.key] = IntentFeedbackStats.fromJson(v);
            }
          }
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    if (!_dirty) return;
    try {
      final p = prefs;
      final store = p ?? await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(_stats.map((k, v) => MapEntry(k, v.toJson())));
      await store.setString(storageKey, encoded);
      _dirty = false;
    } catch (_) {}
  }

  void recordSuccess(String intentId) {
    final s = _stats.putIfAbsent(intentId, IntentFeedbackStats.new);
    s.success += 1;
    s.score = (s.score + 1).clamp(-100.0, 100.0);
    _dirty = true;
    unawaited(_save());
  }

  void recordFailure(String intentId) {
    final s = _stats.putIfAbsent(intentId, IntentFeedbackStats.new);
    s.failure += 1;
    s.score = (s.score - 2).clamp(-100.0, 100.0);
    _dirty = true;
    unawaited(_save());
  }

  void recordAmbiguity(String intentId) {
    _stats.putIfAbsent(intentId, IntentFeedbackStats.new).ambiguity += 1;
    _dirty = true;
    unawaited(_save());
  }

  double confidenceMultiplier(String intentId) {
    final s = _stats[intentId];
    if (s == null || s.total == 0) return 1.0;
    return (0.5 + s.success / max(1, s.total)).clamp(0.5, 1.5);
  }

  bool isDiscouraged(String intentId) {
    final s = _stats[intentId];
    if (s == null || s.total < 3) return false;
    return s.failure / s.total > 0.6;
  }

  void applyDecay() {
    for (final s in _stats.values) {
      s.score *= decay;
    }
    _dirty = true;
    unawaited(_save());
  }

  String? tieBreak(Iterable<String> candidateIds) {
    String? best;
    double bestScore = double.negativeInfinity;
    for (final id in candidateIds) {
      final total = (_stats[id]?.score ?? 0) * confidenceMultiplier(id) +
          _random.nextDouble() * 0.01;
      if (total > bestScore) {
        bestScore = total;
        best = id;
      }
    }
    return best;
  }

  Map<String, IntentFeedbackStats> get stats => Map.unmodifiable(_stats);

  String summary() {
    if (_stats.isEmpty) return 'هنوز بازخوردی برای intentها ثبت نشده.';
    final entries = _stats.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return entries
        .take(8)
        .map((e) =>
            '${e.key}: ${e.value.success} موفق / ${e.value.failure} ناموفق')
        .join('\n');
  }

  void resetForTest() {
    _stats.clear();
    _loaded = false;
    _dirty = false;
  }
}
