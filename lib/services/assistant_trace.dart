import 'dart:collection';
import 'package:flutter/foundation.dart';

/// نوع مرحله در ردپا.
enum TraceStepType {
  input,         // دریافت ورودی
  normalize,     // نرمال‌سازی متن
  memory,        // جستجو/خواندن حافظه
  intent,        // تشخیص نیت
  followup,      // پیگیری ارجاعی (آنافورا)
  routing,       // تصمیم روتر
  online,        // تماس با هوش آنلاین
  local,         // تولید پاسخ محلی
  feedback,      // بازخورد/تصحیح کاربر
  selfHealing,   // رویداد خودترمیمی
  output,        // پاسخ نهایی
  warning,       // هشدار
  error,         // خطا
}

extension TraceStepTypeX on TraceStepType {
  String get label {
    switch (this) {
      case TraceStepType.input: return 'ورودی';
      case TraceStepType.normalize: return 'نرمال‌سازی';
      case TraceStepType.memory: return 'حافظه';
      case TraceStepType.intent: return 'تشخیص نیت';
      case TraceStepType.followup: return 'پیگیری';
      case TraceStepType.routing: return 'مسیریابی';
      case TraceStepType.online: return 'هوش آنلاین';
      case TraceStepType.local: return 'پاسخ محلی';
      case TraceStepType.feedback: return 'بازخورد';
      case TraceStepType.selfHealing: return 'خودترمیمی';
      case TraceStepType.output: return 'خروجی';
      case TraceStepType.warning: return 'هشدار';
      case TraceStepType.error: return 'خطا';
    }
  }

  String get emoji {
    switch (this) {
      case TraceStepType.input: return '📥';
      case TraceStepType.normalize: return '🔤';
      case TraceStepType.memory: return '🧠';
      case TraceStepType.intent: return '🎯';
      case TraceStepType.followup: return '🔗';
      case TraceStepType.routing: return '🛣️';
      case TraceStepType.online: return '🌐';
      case TraceStepType.local: return '📱';
      case TraceStepType.feedback: return '👍';
      case TraceStepType.selfHealing: return '♻️';
      case TraceStepType.output: return '📤';
      case TraceStepType.warning: return '⚠️';
      case TraceStepType.error: return '❌';
    }
  }
}

/// یک مرحلهٔ کامل با تمام اطلاعات لازم برای دیباگ حرفه‌ای.
class TraceStep {
  final DateTime time;
  final TraceStepType type;
  final String title;

  /// نام فایل/تابع کد منبع (برای پیدا کردن سریع محل).
  final String? source;

  /// داده‌های ورودی به این مرحله.
  final Map<String, dynamic> inputs;

  /// داده‌های خروجی/نتیجه.
  final Map<String, dynamic> outputs;

  /// مدت زمان اجرای این مرحله.
  final Duration? duration;

  /// آیا این مرحله با موفقیت انجام شد؟
  final bool success;

  /// پیام خطا (اگر شکست خورده باشد).
  final String? errorMessage;

  TraceStep({
    required this.type,
    required this.title,
    this.source,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
    this.duration,
    this.success = true,
    this.errorMessage,
  })  : inputs = inputs ?? {},
        outputs = outputs ?? {},
        time = DateTime.now();

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'type': type.name,
        'title': title,
        if (source != null) 'source': source,
        if (inputs.isNotEmpty) 'inputs': inputs,
        if (outputs.isNotEmpty) 'outputs': outputs,
        if (duration != null) 'duration_ms': duration!.inMilliseconds,
        'ok': success,
        if (errorMessage != null) 'error': errorMessage,
      };

  /// خروجی متنی دقیق برای گزارش.
  String format(int index) {
    final buf = StringBuffer();
    buf.writeln('$index. ${type.emoji} [$title]');
    if (source != null) buf.writeln('   📍 $source');
    if (duration != null) buf.writeln('   ⏱️  ${duration!.inMilliseconds}ms');
    if (inputs.isNotEmpty) {
      buf.writeln('   📥 ورودی‌ها:');
      inputs.forEach((k, v) => buf.writeln('      • $k = $_short(v)'));
    }
    if (outputs.isNotEmpty) {
      buf.writeln('   📤 خروجی‌ها:');
      outputs.forEach((k, v) => buf.writeln('      • $k = $_short(v)'));
    }
    if (errorMessage != null) {
      buf.writeln('   ❌ خطا: $errorMessage');
    }
    return buf.toString().trimRight();
  }

  static String _short(dynamic v) {
    var s = v?.toString() ?? 'null';
    if (s.length > 200) s = '${s.substring(0, 197)}...';
    return s;
  }
}

/// ردپای کامل یک درخواست دستیار.
class AssistantTrace {
  final DateTime startedAt;
  final String userText;
  final List<TraceStep> steps = [];
  final Map<String, dynamic> metadata = {};
  final Stopwatch _sw = Stopwatch()..start();

  AssistantTrace({required this.userText}) : startedAt = DateTime.now();

  /// ثبت یک مرحلهٔ ساده.
  TraceStep step(
    TraceStepType type,
    String title, {
    String? source,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
    bool success = true,
    String? error,
  }) {
    final s = TraceStep(
      type: type,
      title: title,
      source: source,
      inputs: inputs,
      outputs: outputs,
      duration: _sw.elapsed,
      success: success,
      errorMessage: error,
    );
    steps.add(s);
    if (kDebugMode) debugPrint('🔍 [trace] $title');
    return s;
  }

  /// ثبت خطا.
  void error(
    TraceStepType type,
    String title,
    Object error, {
    String? source,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
  }) {
    step(type, title,
        source: source,
        inputs: inputs,
        outputs: outputs,
        success: false,
        error: error.toString());
  }

  void set(String key, dynamic value) => metadata[key] = value;

  /// گزارش کامل حرفه‌ای.
  String toReport() {
    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════════════════');
    buf.writeln('🔍 گزارش دیباگ دستیار هوشمند');
    buf.writeln('═══════════════════════════════════════════════');
    buf.writeln('📝 ورودی: "$userText"');
    buf.writeln('🕐 شروع: $startedAt');
    buf.writeln('🔢 تعداد مراحل: ${steps.length}');
    final errors = steps.where((s) => !s.success).length;
    final warnings = steps.where((s) => s.type == TraceStepType.warning).length;
    buf.writeln('✅ موفق، ⚠️  $warnings هشدار، ❌ $errors خطا');

    // خلاصهٔ مسیر طی‌شده
    final path = steps.map((s) => s.type.emoji).join(' → ');
    buf.writeln('🛤️  مسیر: $path');

    if (metadata.isNotEmpty) {
      buf.writeln('📎 متادیتا:');
      metadata.forEach((k, v) => buf.writeln('   • $k = $v'));
    }

    buf.writeln('───────────────────────────────────────────────');
    buf.writeln('📋 جزئیات مراحل:');
    buf.writeln('───────────────────────────────────────────────');
    for (var i = 0; i < steps.length; i++) {
      buf.writeln(steps[i].format(i + 1));
      if (i < steps.length - 1) buf.writeln();
    }

    buf.writeln('───────────────────────────────────────────────');
    buf.writeln('⏱️  مجموع زمان: ${_sw.elapsed.inMilliseconds}ms');
    if (errors == 0) {
      buf.writeln('✅ پایان موفق — هیچ خطایی نبود');
    } else {
      buf.writeln('❌ $errors مرحله با خطا مواجه شد (با ❌ مشخص شده)');
    }
    buf.writeln('═══════════════════════════════════════════════');
    return buf.toString();
  }

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
  static const _maxTraces = 30;
  final Queue<AssistantTrace> _traces = Queue();
  AssistantTrace? get last => _traces.isEmpty ? null : _traces.last;
  List<AssistantTrace> get all => _traces.toList();
  AssistantTrace start(String userText) {
    final t = AssistantTrace(userText: userText);
    _traces.add(t);
    while (_traces.length > _maxTraces) _traces.removeFirst();
    return t;
  }
  void clear() => _traces.clear();
}
