import 'dart:math';

/// یادگیری سبک از بازخورد کاربر روی پاسخ‌های محلی — بدون نیاز به آنلاین.
class IntentFeedbackStore {
  IntentFeedbackStore({this.decay = 0.98, int? seed})
      : _random = Random(seed);

  final double decay;
  final Random _random;
  final Map<String, IntentFeedbackStats> _stats = {};

  void recordSuccess(String intentId) {
    final s = _stats.putIfAbsent(intentId, IntentFeedbackStats.new);
    s.success += 1;
    s.score = (s.score + 1).clamp(-100.0, 100.0);
  }

  void recordFailure(String intentId) {
    final s = _stats.putIfAbsent(intentId, IntentFeedbackStats.new);
    s.failure += 1;
    s.score = (s.score - 2).clamp(-100.0, 100.0);
  }

  void recordAmbiguity(String intentId) {
    _stats.putIfAbsent(intentId, IntentFeedbackStats.new).ambiguity += 1;
  }

  double confidenceMultiplier(String intentId) {
    final s = _stats[intentId];
    if (s == null || s.total == 0) return 1.0;
    final ratio = s.success / max(1, s.total);
    return (0.5 + ratio).clamp(0.5, 1.5);
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
  }

  String? tieBreak(Iterable<String> candidateIds) {
    String? best;
    double bestScore = double.negativeInfinity;
    for (final id in candidateIds) {
      final total =
          (_stats[id]?.score ?? 0) * confidenceMultiplier(id) + _random.nextDouble() * 0.01;
      if (total > bestScore) {
        bestScore = total;
        best = id;
      }
    }
    return best;
  }

  Map<String, IntentFeedbackStats> get stats => Map.unmodifiable(_stats);

  Map<String, dynamic> toJson() => _stats.map(
        (k, v) => MapEntry(k, {
              'success': v.success,
              'failure': v.failure,
              'ambiguity': v.ambiguity,
              'score': v.score,
            }),
      );

  void loadJson(Map<String, dynamic> json) {
    _stats.clear();
    for (final e in json.entries) {
      final v = e.value;
      if (v is Map) {
        _stats[e.key] = IntentFeedbackStats()
          ..success = (v['success'] as num?)?.toInt() ?? 0
          ..failure = (v['failure'] as num?)?.toInt() ?? 0
          ..ambiguity = (v['ambiguity'] as num?)?.toInt() ?? 0
          ..score = (v['score'] as num?)?.toDouble() ?? 0;
      }
    }
  }

  void clear() => _stats.clear();
}

class IntentFeedbackStats {
  int success = 0;
  int failure = 0;
  int ambiguity = 0;
  double score = 0;
  int get total => success + failure;
}
