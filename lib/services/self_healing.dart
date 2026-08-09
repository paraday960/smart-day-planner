import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// یک خطای ثبت‌شده در سیستم.
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

/// سیستم خودعیب‌یابی و خودترمیمی.
///
/// - تمام خطاها را ثبت می‌کند
/// - خطاهای تکراری را تشخیص می‌دهد
/// - اگر یک قابلیت چند بار خطا بدهد، آن را موقتاً غیرفعال می‌کند
///   (با [isFeatureDisabled]) و به مسیر جایگزین می‌رود
/// - پس از مدتی دوباره تلاش می‌کند (healing)
/// - خلاصهٔ خطاها را برای گزارش در اختیار می‌گذارد
class SelfHealing {
  SelfHealing._();
  static final SelfHealing instance = SelfHealing._();

  static const _maxRecords = 200;
  static const _failureThreshold = 3;
  static const _healingDuration = Duration(hours: 6);

  final Queue<_ErrorRecord> _errors = Queue();
  final Map<String, _ErrorRecord> _indexed = {};

  /// قابلیت‌هایی که به‌خاطر خطاهای مکرر موقتاً غیرفعال شده‌اند.
  final Map<String, DateTime> _disabledFeatures = {};

  /// گزارش یک خطا.
  ///
  /// [feature] نام قابلیت (مثلاً 'online_ai', 'voice_input').
  /// اگر خطا به‌اندازهٔ کافی تکرار شود، آن قابلیت به‌طور موقت غیرفعال می‌شود.
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

    // شمارش خطاهای همین قابلیت
    final featureFailures = _indexed.values
        .where((e) => e.where == feature)
        .fold<int>(0, (sum, e) => sum + e.count);

    if (featureFailures >= _failureThreshold &&
        !_disabledFeatures.containsKey(feature)) {
      _disabledFeatures[feature] = now;
      debugPrint(
          '🔧 Self-healing: قابلیت «$feature» به‌خاطر $featureFailures خطا موقتاً غیرفعال شد.');
    }

    if (kDebugMode) {
      debugPrint('🐞 SelfHealing[$feature]: $error');
    }
  }

  /// آیا این قابلیت به‌خاطر خطاهای مکرر غیرفعال است؟
  bool isFeatureDisabled(String feature) {
    final disabledAt = _disabledFeatures[feature];
    if (disabledAt == null) return false;
    if (DateTime.now().difference(disabledAt) > _healingDuration) {
      // شفای خودکار: دوباره فعال کن
      _disabledFeatures.remove(feature);
      debugPrint('♻️ Self-healing: قابلیت «$feature» دوباره فعال شد.');
      return false;
    }
    return true;
  }

  /// اجرای امن یک عملیات با خودترمیمی.
  ///
  /// اگر [feature] غیرفعال باشد یا عملیات خطا بدهد، [fallback] اجرا می‌شود.
  Future<T> guard<T>(
    Future<T> Function() action, {
    required String feature,
    required T Function(Object error) fallback,
  }) async {
    if (isFeatureDisabled(feature)) {
      return fallback(
          StateError('قابلیت $feature موقتاً غیرفعال است (self-healing)'));
    }
    try {
      return await action();
    } catch (e, st) {
      reportError(e, feature: feature, stack: st.toString());
      return fallback(e);
    }
  }

  /// نسخهٔ همگام guard.
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

  /// همهٔ خطاها (برای نمایش در صفحهٔ دیباگ).
  List<Map<String, dynamic>> get recentErrors => _errors
      .map((e) => {
            'feature': e.where,
            'error': e.error,
            'count': e.count,
            'at': e.at.toIso8601String(),
          })
      .toList()
    ..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));

  /// قابلیت‌های غیرفعال.
  Map<String, String> get disabledFeatures => _disabledFeatures
      .map((k, v) => MapEntry(k, v.toIso8601String()));

  /// خلاصهٔ وضعیت برای گزارش.
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
    if (_errors.isNotEmpty) {
      buf.writeln('آخرین خطاها:');
      for (final e in _errors.take(5)) {
        buf.writeln('  [${e.where}] x${e.count}: ${e.error}');
      }
    }
    return buf.toString();
  }

  /// پاک کردن همهٔ خطاها و بازنشانی.
  void clear() {
    _errors.clear();
    _indexed.clear();
    _disabledFeatures.clear();
  }
}
