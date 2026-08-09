import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// یک رویداد در سیستم خودترمیمی.
class HealingEvent {
  final DateTime time;
  final String feature;
  final String action; // 'error' | 'disabled' | 'healed' | 'fallback'
  final String? detail;
  HealingEvent({
    required this.feature,
    required this.action,
    this.detail,
  }) : time = DateTime.now();

  String get emoji {
    switch (action) {
      case 'error':
        return '🐞';
      case 'disabled':
        return '⏸️';
      case 'healed':
        return '♻️';
      case 'fallback':
        return '🔁';
      default:
        return '•';
    }
  }

  String get label {
    switch (action) {
      case 'error':
        return 'خطا ثبت شد';
      case 'disabled':
        return 'غیرفعال‌سازی موقت';
      case 'healed':
        return 'شفای خودکار';
      case 'fallback':
        return 'استفاده از مسیر جایگزین';
      default:
        return action;
    }
  }

  @override
  String toString() =>
      '$emoji [$feature] $label${detail != null ? " — $detail" : ""}';
}

class _ErrorRecord {
  final String error;
  final String? stack;
  final String where;
  final DateTime at;
  int count;
  _ErrorRecord({
    required this.error,
    required this.where,
    this.stack,
    required this.at,
    this.count = 1,
  });

  String get signature => '$where::${error.split('\n').first}';
}

class SelfHealing {
  SelfHealing._();
  static final SelfHealing instance = SelfHealing._();

  static const _maxRecords = 200;
  static const _maxEvents = 50;
  static const _failureThreshold = 3;
  static const _healingDuration = Duration(hours: 6);

  final Queue<_ErrorRecord> _errors = Queue();
  final Map<String, _ErrorRecord> _indexed = {};
  final Map<String, DateTime> _disabledFeatures = {};

  /// رویدادهای اخیر خودترمیمی (برای نمایش در ردپا).
  final Queue<HealingEvent> events = Queue();

  void _log(HealingEvent e) {
    events.add(e);
    while (events.length > _maxEvents) {
      events.removeFirst();
    }
    if (kDebugMode) {
      debugPrint('${e.emoji} SelfHealing[${e.feature}]: ${e.label}');
    }
  }

  /// آخرین رویدادهای مربوط به یک قابلیت.
  List<HealingEvent> eventsFor(String feature) =>
      events.where((e) => e.feature == feature).toList();

  void reportError(
    Object error, {
    required String feature,
    String? stack,
  }) {
    final now = DateTime.now();
    final rec = _ErrorRecord(
      error: error.toString(),
      where: feature,
      stack: stack,
      at: now,
    );
    final sig = rec.signature;

    if (_indexed.containsKey(sig)) {
      _indexed[sig]!.count++;
    } else {
      _indexed[sig] = rec;
      _errors.add(rec);
      while (_errors.length > _maxRecords) {
        final old = _errors.removeFirst();
        _indexed.remove(old.signature);
      }
    }

    _log(HealingEvent(
        feature: feature, action: 'error', detail: error.toString()));

    final failures = _indexed.values
        .where((e) => e.where == feature)
        .fold<int>(0, (sum, e) => sum + e.count);

    if (failures >= _failureThreshold &&
        !_disabledFeatures.containsKey(feature)) {
      _disabledFeatures[feature] = now;
      _log(HealingEvent(
        feature: feature,
        action: 'disabled',
        detail: 'پس از $failures خطا، به‌مدت ۶ ساعت غیرفعال شد',
      ));
    }
  }

  bool isFeatureDisabled(String feature) {
    final disabledAt = _disabledFeatures[feature];
    if (disabledAt == null) return false;
    if (DateTime.now().difference(disabledAt) > _healingDuration) {
      _disabledFeatures.remove(feature);
      _log(HealingEvent(
        feature: feature,
        action: 'healed',
        detail: 'پس از ۶ ساعت دوباره فعال شد',
      ));
      return false;
    }
    return true;
  }

  Future<T> guard<T>(
    Future<T> Function() action, {
    required String feature,
    required T Function(Object error) fallback,
  }) async {
    if (isFeatureDisabled(feature)) {
      _log(HealingEvent(
        feature: feature,
        action: 'fallback',
        detail: 'قابلیت غیرفعال است، مسیر جایگزین اجرا شد',
      ));
      return fallback(
          StateError('قابلیت $feature موقتاً غیرفعال است (self-healing)'));
    }
    try {
      return await action();
    } catch (e, st) {
      reportError(e, feature: feature, stack: st.toString());
      _log(HealingEvent(
        feature: feature,
        action: 'fallback',
        detail: 'خطا رخ داد، مسیر جایگزین اجرا شد',
      ));
      return fallback(e);
    }
  }

  T guardSync<T>(
    T Function() action, {
    required String feature,
    required T Function(Object error) fallback,
  }) {
    if (isFeatureDisabled(feature)) {
      return fallback(
          StateError('قابلیت $feature موقتاً غیرفعال است (self-healing)'));
    }
    try {
      return action();
    } catch (e, st) {
      reportError(e, feature: feature, stack: st.toString());
      return fallback(e);
    }
  }

  List<Map<String, dynamic>> get recentErrors => _errors
      .map((e) => {
            'feature': e.where,
            'error': e.error,
            'count': e.count,
            'at': e.at.toIso8601String(),
          })
      .toList()
    ..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));

  Map<String, String> get disabledFeatures =>
      _disabledFeatures.map((k, v) => MapEntry(k, v.toIso8601String()));

  String get summary {
    final buf = StringBuffer();
    buf.writeln('🧠 Self-Healing Report');
    buf.writeln('خطاهای ثبت‌شده: ${_errors.length}');
    if (_disabledFeatures.isNotEmpty) {
      buf.writeln('⚠️ قابلیت‌های غیرفعال:');
      _disabledFeatures.forEach((k, v) {
        buf.writeln('  • $k (از ${v.toIso8601String()})');
      });
    }
    if (events.isNotEmpty) {
      buf.writeln('آخرین رویدادها:');
      for (final e in events.toList().reversed.take(10)) {
        buf.writeln('  $e');
      }
    }
    return buf.toString();
  }

  void clear() {
    _errors.clear();
    _indexed.clear();
    _disabledFeatures.clear();
    events.clear();
  }
}
