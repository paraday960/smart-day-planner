import 'dart:collection';
import 'package:flutter/foundation.dart';

enum TraceLevel { info, success, warning, error }

class AppCategory {
  static const assistant = 'assistant';
  static const task = 'task';
  static const finance = 'finance';
  static const debt = 'debt';
  static const goal = 'goal';
  static const settings = 'settings';
  static const voice = 'voice';
  static const notification = 'notification';
  static const security = 'security';
  static const system = 'system';
}

class AppTraceEvent {
  final DateTime time;
  final String category;
  final String action;
  final TraceLevel level;
  final String? source;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> outputs;
  final Duration? duration;
  final String? errorMessage;

  AppTraceEvent({
    required this.category,
    required this.action,
    this.level = TraceLevel.info,
    this.source,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
    this.duration,
    this.errorMessage,
  })  : inputs = inputs ?? {},
        outputs = outputs ?? {},
        time = DateTime.now();

  String get emoji {
    switch (level) {
      case TraceLevel.success: return '✅';
      case TraceLevel.warning: return '⚠️';
      case TraceLevel.error: return '❌';
      case TraceLevel.info: default: return '•';
    }
  }

  String get categoryLabel {
    switch (category) {
      case AppCategory.assistant: return '🤖 دستیار';
      case AppCategory.task: return '📋 کارها';
      case AppCategory.finance: return '💰 مالی';
      case AppCategory.debt: return '💳 بدهی';
      case AppCategory.goal: return '🎯 هدف';
      case AppCategory.settings: return '⚙️ تنظیمات';
      case AppCategory.voice: return '🎤 صدا';
      case AppCategory.notification: return '🔔 اعلان';
      case AppCategory.security: return '🔒 امنیت';
      default: return '📱 سیستم';
    }
  }

  String format() {
    final buf = StringBuffer('$emoji [$categoryLabel] $action');
    if (duration != null) buf.write(' (${duration!.inMilliseconds}ms)');
    buf.writeln();
    if (source != null) buf.writeln('   📍 $source');
    if (inputs.isNotEmpty) {
      buf.writeln('   📥 ورودی‌ها:');
      inputs.forEach((k, v) => buf.writeln('      • $k = ${_short(v)}'));
    }
    if (outputs.isNotEmpty) {
      buf.writeln('   📤 خروجی‌ها:');
      outputs.forEach((k, v) => buf.writeln('      • $k = ${_short(v)}'));
    }
    if (errorMessage != null) buf.writeln('   ❌ خطا: $errorMessage');
    return buf.toString().trimRight();
  }

  static String _short(dynamic v) {
    final s = v?.toString() ?? 'null';
    return s.length > 200 ? '${s.substring(0, 197)}...' : s;
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'category': category,
        'action': action,
        'level': level.name,
        if (source != null) 'source': source,
        if (inputs.isNotEmpty) 'inputs': inputs,
        if (outputs.isNotEmpty) 'outputs': outputs,
        if (duration != null) 'duration_ms': duration!.inMilliseconds,
        if (errorMessage != null) 'error': errorMessage,
      };
}

class AppTrace {
  AppTrace._();
  static final AppTrace instance = AppTrace._();
  static const _maxEvents = 500;
  final Queue<AppTraceEvent> _events = Queue();
  List<AppTraceEvent> get events => _events.toList().reversed.toList();

  AppTraceEvent log(String category, String action,
      {TraceLevel level = TraceLevel.info,
      String? source,
      Map<String, dynamic>? inputs,
      Map<String, dynamic>? outputs,
      Duration? duration,
      String? error}) {
    final e = AppTraceEvent(
        category: category, action: action, level: level, source: source,
        inputs: inputs, outputs: outputs, duration: duration, errorMessage: error);
    _events.add(e);
    while (_events.length > _maxEvents) _events.removeFirst();
    if (kDebugMode) debugPrint('🔍 [app-trace] $e');
    return e;
  }

  Future<T> track<T>(String category, String action, Future<T> Function() operation,
      {String? source, Map<String, dynamic>? inputs,
      Map<String, dynamic> Function(T)? outputsFrom}) async {
    final sw = Stopwatch()..start();
    try {
      final r = await operation();
      sw.stop();
      log(category, action, level: TraceLevel.success, source: source,
          duration: sw.elapsed, inputs: inputs, outputs: outputsFrom?.call(r));
      return r;
    } catch (e) {
      sw.stop();
      log(category, action, level: TraceLevel.error, source: source,
          duration: sw.elapsed, inputs: inputs, error: e.toString());
      rethrow;
    }
  }

  List<AppTraceEvent> eventsFor(String c) =>
      _events.where((e) => e.category == c).toList().reversed.toList();

  String toReport() {
    final b = StringBuffer()
      ..writeln('═══════════════════════════════════════════════')
      ..writeln('📋 گزارش کامل ردپای برنامه')
      ..writeln('═══════════════════════════════════════════════')
      ..writeln('تعداد رویدادها: ${_events.length}');
    final byCat = <String, int>{};
    for (final e in _events) byCat[e.category] = (byCat[e.category] ?? 0) + 1;
    byCat.forEach((k, v) => b.writeln('  • $k: $v'));
    final errs = _events.where((e) => e.level == TraceLevel.error).length;
    b.writeln(errs > 0 ? '❌ خطاها: $errs' : '✅ هیچ خطایی ثبت نشده');
    b.writeln('═══════════════════════════════════════════════');
    for (final e in _events.toList().reversed.take(60)) {
      b.writeln(e.format());
      b.writeln();
    }
    return b.toString();
  }

  void clear() => _events.clear();
}
