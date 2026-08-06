/// حافظهٔ کوتاه‌مدت مکالمه — برای پرسش‌های دنباله‌دار.
///
/// به دستیار اجازه می‌دهد بفهمد «بعدش چی؟» یا «حالا چی؟» به کدام
/// پاسخ قبلی اشاره دارد و پاسخ مرتبط بدهد. این حافظه فقط در حافظهٔ
/// RAM می‌ماند (بین اجراهای اپ پاک می‌شود) — چیزی روی دیسک نمی‌نویسد.
class DialogueMemory {
  /// حداکثر تعداد نوبت‌هایی که به خاطر می‌سپاریم.
  static const int _maxTurns = 8;

  final List<DialogueTurn> _turns = [];

  /// ثبت یک نوبت گفتگو.
  void remember({
    required String prompt,
    required String response,
    String? intent,
  }) {
    _turns.add(DialogueTurn(
      prompt: prompt,
      response: response,
      intent: intent,
      at: DateTime.now(),
    ));
    if (_turns.length > _maxTurns) {
      _turns.removeAt(0);
    }
  }

  /// آخرین نوبت (یا null اگر مکالمه‌ای نبوده).
  DialogueTurn? get last => _turns.isEmpty ? null : _turns.last;

  /// قصد آخرین نوبت.
  String? get lastIntent => last?.intent;

  /// آخرین پرسش کاربر.
  String? get lastPrompt => last?.prompt;

  /// آخرین پاسخ دستیار.
  String? get lastResponse => last?.response;

  /// تعداد نوبت‌های ذخیره‌شده.
  int get length => _turns.length;

  /// پاک‌کردن حافظه (مثلاً با شروع مکالمهٔ جدید).
  void clear() => _turns.clear();

  /// آیا آخرین قصد با [intent] یکی است؟
  bool lastWas(String intent) => lastIntent == intent;
}

/// یک نوبت گفتگو.
class DialogueTurn {
  const DialogueTurn({
    required this.prompt,
    required this.response,
    required this.at,
    this.intent,
  });

  final String prompt;
  final String response;
  final String? intent;
  final DateTime at;
}
