import 'dart:collection';
import 'package:flutter/foundation.dart';

/// اهمیت رویداد.
enum TraceLevel { info, success, warning, error }

/// یک رویداد در ردپای برنامه.
class AppTraceEvent {
  final DateTime time;
  final String category; // 'assistant' | 'task' | 'finance' | 'debt' | 'goal' | 'settings' | 'voice' | 'system'
  final String action;
  final TraceLevel level;
  final String? detail;
  final Duration? duration;

  AppTraceEvent({
    required this.category,
    required this.action,
    this.level = TraceLevel.info,
    this.detail,
    this.duration,
  }) : time = DateTime.now();

  String get emoji {
    switch (level) {
      case TraceLevel.success:
        return '✅';
      case TraceLevel.warning:
        return '⚠️';
      case TraceLevel.error:
        return '❌';
      case TraceLevel.info:
      default:
        return '•';
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'assistant':
        return '🤖 دستیار';
      case 'task':
        return '📋 کارها';
      case 'finance':
        return '💰 مالی';
      case 'debt':
        return '💳 بدهی';
      case 'goal':
        return '🎯 هدف';
      case 'settings':
        return '⚙️ تنظیمات';
      case 'voice':
        return '🎤 صدا';
      case 'notification':
        return '🔔 اعلان';
      case 'security':
        return '🔒 امنیت';
      case 'system':
      default:
        return '📱 سیستم';
    }
  }

  @override
  String toString() {
    final buf = StringBuffer('$emoji [$categoryLabel] $action');
    if (duration != null) buf.write(' (${duration!.inMilliseconds}ms)');
    buf.writeln();
    if (detail != null && detail!.trim().isNotEmpty) {
      for (final line in detail!.split('\n')) {
        buf.writeln('    $line');
      }
    }
    return buf.toString().trimRight();
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'category': category,
        'action': action,
        'level': level.name,
        if (detail != null) 'detail': detail,
        if (duration != null) 'duration_ms': duration!.inMilliseconds,
      };
}

/// ردپای سراسری برنامه — تمام عملیات مهم را ثبت می‌کند.
///
/// برخلاف [AssistantTrace] که فقط یک درخواست دستیار را ردیابی می‌کند،
/// این کلاس رویدادهای سراسری (ثبت کار، تراکنش، تنظیمات و...) را نگه می‌دارد.
class AppTrace {
  AppTrace._();
  static final AppTrace instance = AppTrace._();

  static const _maxEvents = 500;
  final Queue<AppTraceEvent> _events = Queue();

  /// آخرین رویدادها (جدیدترین‌ها اول).
  List<AppTraceEvent> get events => _events.toList().reversed.toList();

  /// ثبت یک رویداد.
  void log(
    String category,
    String action, {
    TraceLevel level = TraceLevel.info,
    String? detail,
    Duration? duration,
  }) {
    final e = AppTraceEvent(
      category: category,
      action: action,
      level: level,
      detail: detail,
      duration: duration,
    );
    _events.add(e);
    while (_events.length > _maxEvents) {
      _events.removeFirst();
    }
    if (kDebugMode) {
      debugPrint('🔍 [trace] $e');
    }
  }

  /// اجرای یک عملیات با اندازه‌گیری زمان و ثبت خودکار.
  Future<T> track<T>(
    String category,
    String action,
    Future<T> Function() operation, {
    String? Function(T result)? detailFromResult,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await operation();
      sw.stop();
      log(
        category,
        action,
        level: TraceLevel.success,
        duration: sw.elapsed,
        detail: detailFromResult?.call(result),
      );
      return result;
    } catch (e) {
      sw.stop();
      log(
        category,
        action,
        level: TraceLevel.error,
        duration: sw.elapsed,
        detail: e.toString(),
      );
      rethrow;
    }
  }

  /// نسخهٔ همگام [track].
  T trackSync<T>(
    String category,
    String action,
    T Function() operation, {
    String? Function(T)? detailFromResult,
  }) {
    final sw = Stopwatch()..start();
    try {
      final result = operation();
      sw.stop();
      log(
        category,
        action,
        level: TraceLevel.success,
        duration: sw.elapsed,
        detail: detailFromResult?.call(result),
      );
      return result;
    } catch (e) {
      sw.stop();
      log(category, action,
          level: TraceLevel.error, duration: sw.elapsed, detail: e.toString());
      rethrow;
    }
  }

  /// رویدادهای یک دسته‌بندی خاص.
  List<AppTraceEvent> eventsFor(String category) =>
      _events.where((e) => e.category == category).toList().reversed.toList();

  /// خلاصهٔ وضعیت برای گزارش.
  String get summary {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════');
    buf.writeln('📋 گزارش کامل ردپای برنامه');
    buf.writeln('═══════════════════════════════════');
    buf.writeln('تعداد رویدادها: ${_events.length}');
    final byCat = <String, int>{};
    for (final e in _events) {
      byCat[e.category] = (byCat[e.category] ?? 0) + 1;
    }
    if (byCat.isNotEmpty) {
      buf.writeln('بر اساس دسته:');
      byCat.forEach((k, v) => buf.writeln('  • $k: $v'));
    }
    final errors = _events.where((e) => e.level == TraceLevel.error).length;
    if (errors > 0) {
      buf.writeln('⚠️ خطاها: $errors');
    } else {
      buf.writeln('✅ هیچ خطایی ثبت نشده');
    }
    buf.writeln('═══════════════════════════════════');
    return buf.toString();
  }

  /// گزارش متنی کامل برای کپی.
  String toReport() {
    final buf = StringBuffer(summary);
    final recent = _events.toList().reversed.take(50);
    for (final e in recent) {
      buf.writeln(e.toString());
    }
    buf.writeln('═══════════════════════════════════');
    return buf.toString();
  }

  void clear() {
    _events.clear();
  }
}
