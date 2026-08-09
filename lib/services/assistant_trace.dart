import 'dart:collection';
import 'package:flutter/foundation.dart';

/// یک مرحله از پردازش درخواست کاربر.
class TraceStep {
  final DateTime time;
  final String title;
  final String? detail;
  final Duration? duration;
  final bool success;

  TraceStep({
    required this.title,
    this.detail,
    this.duration,
    this.success = true,
  }) : time = DateTime.now();

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'title': title,
        if (detail != null) 'detail': detail,
        if (duration != null) 'duration_ms': duration!.inMilliseconds,
        'ok': success,
      };

  @override
  String toString() {
    final sw = Stopwatch()..start();
    final buf = StringBuffer();
    buf.write('${success ? "✅" : "❌"} $title');
    if (duration != null) {
      buf.write(' (${duration!.inMilliseconds}ms)');
    }
    buf.writeln();
    if (detail != null && detail!.trim().isNotEmpty) {
      for (final line in detail!.split('\n')) {
        buf.writeln('    $line');
      }
    }
    sw.stop();
    return buf.toString();
  }
}

/// ردیابی کامل پردازش یک درخواست در دستیار.
///
/// هر مرحله (تشخیص intent، تصمیم روتر، جستجو در حافظه،
/// تماس آنلاین، یادگیری و...) به این رکورد اضافه می‌شود
/// و در یک صفحهٔ دیباگ قابل مشاهده و کپی است.
class AssistantTrace {
  final DateTime startedAt;
  final String userText;
  final List<TraceStep> steps = [];
  final Map<String, dynamic> metadata = {};

  AssistantTrace({required this.userText})
      : startedAt = DateTime.now();

  final Stopwatch _sw = Stopwatch()..start();

  /// افزودن یک مرحله.
  void step(String title, {String? detail, bool success = true}) {
    final s = TraceStep(
      title: title,
      detail: detail,
      duration: _sw.elapsed,
      success: success,
    );
    steps.add(s);
    if (kDebugMode) {
      debugPrint('🔍 [trace] ${s.title}');
    }
  }

  /// مرحله‌ای که شامل خطا است.
  void error(String title, Object error, [String? detail]) {
    step(title,
        detail: '${detail ?? ''}\n❌ خطا: $error',
        success: false);
  }

  void set(String key, dynamic value) {
    metadata[key] = value;
  }

  /// خروجی متنی قابل کپی برای ارسال به توسعه‌دهنده.
  String toReport() {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════');
    buf.writeln('🔍 گزارش دیباگ دستیار هوشمند');
    buf.writeln('═══════════════════════════════════');
    buf.writeln('📝 ورودی: "$userText"');
    buf.writeln('⏱️  شروع: $startedAt');
    buf.writeln('🔢 تعداد مراحل: ${steps.length}');
    if (metadata.isNotEmpty) {
      buf.writeln('📎 متادیتا:');
      metadata.forEach((k, v) => buf.writeln('   • $k = $v'));
    }
    buf.writeln('───────────────────────────────────');
    for (var i = 0; i < steps.length; i++) {
      buf.writeln('${i + 1}. ${steps[i]}');
    }
    final total = _sw.elapsed;
    buf.writeln('───────────────────────────────────');
    buf.writeln('⏱️  مجموع زمان: ${total.inMilliseconds}ms');
    final errors = steps.where((s) => !s.success).length;
    buf.writeln(errors == 0
        ? '✅ هیچ خطایی نبود'
        : '⚠️  $errors مرحله با خطا مواجه شد');
    buf.writeln('═══════════════════════════════════');
    return buf.toString();
  }

  /// خروجی فشرده برای لاگ.
  Map<String, dynamic> toJson() => {
        'user_text': userText,
        'started_at': startedAt.toIso8601String(),
        'total_ms': _sw.elapsed.inMilliseconds,
        'steps': steps.map((s) => s.toJson()).toList(),
        'metadata': metadata,
      };
}

/// نگه‌داری ردپای آخرین درخواست‌ها.
class TraceStore {
  TraceStore._();
  static final TraceStore instance = TraceStore._();

  static const _maxTraces = 20;
  final Queue<AssistantTrace> _traces = Queue();

  AssistantTrace? get last => _traces.isEmpty ? null : _traces.last;

  List<AssistantTrace> get all => _traces.toList();

  AssistantTrace start(String userText) {
    final t = AssistantTrace(userText: userText);
    _traces.add(t);
    while (_traces.length > _maxTraces) {
      _traces.removeFirst();
    }
    return t;
  }

  void clear() {
    _traces.clear();
  }
}
