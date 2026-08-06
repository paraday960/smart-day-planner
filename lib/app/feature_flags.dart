class FeatureFlags {
  const FeatureFlags._();

  /// برای ساخت نسخه پایدار اولیه می‌توان قابلیت‌های پرریسک را با dart-define خاموش کرد.
  /// مثال:
  /// flutter run --dart-define=ENABLE_CALENDAR=false
  static const enableVoiceInput =
      bool.fromEnvironment('ENABLE_VOICE_INPUT', defaultValue: true);
  static const enableVoiceResponse =
      bool.fromEnvironment('ENABLE_VOICE_RESPONSE', defaultValue: true);
  static const enableCalendar =
      bool.fromEnvironment('ENABLE_CALENDAR', defaultValue: true);
  static const enablePdfExport =
      bool.fromEnvironment('ENABLE_PDF_EXPORT', defaultValue: true);
  static const enableShareFiles =
      bool.fromEnvironment('ENABLE_SHARE_FILES', defaultValue: true);
  static const enableSmartNotifications =
      bool.fromEnvironment('ENABLE_SMART_NOTIFICATIONS', defaultValue: true);
  static const enableEncryptedBackup =
      bool.fromEnvironment('ENABLE_ENCRYPTED_BACKUP', defaultValue: true);

  /// LLM محلی (llama.cpp و امثال آن) — پیش‌فرض خاموش است چون
  /// مدل‌ها سنگین‌اند و باید جداگانه به اپ اضافه شوند.
  /// وقتی روشن باشد، [HybridLocalAssistant] سعی می‌کند از مدل استفاده کند
  /// و اگر در دسترس نبود خودکار به موتور قانون‌محور برمی‌گردد.
  static const enableLocalLlm =
      bool.fromEnvironment('ENABLE_LOCAL_LLM', defaultValue: false);

  /// تشخیص گفتار آفلاین با Vosk — پیش‌فرض خاموش است چون مدل فارسی
  /// (~۴۰MB) باید جداگانه دانلود شود. وقتی روشن باشد و مدل موجود باشد،
  /// فرمان صوتی بدون اینترنت کار می‌کند؛ در غیر این صورت به سرویس
  /// آنلاین گوشی برمی‌گردد.
  static const enableOfflineSpeech =
      bool.fromEnvironment('ENABLE_OFFLINE_SPEECH', defaultValue: false);

  static Map<String, bool> asMap() => {
        'voiceInput': enableVoiceInput,
        'voiceResponse': enableVoiceResponse,
        'calendar': enableCalendar,
        'pdfExport': enablePdfExport,
        'shareFiles': enableShareFiles,
        'smartNotifications': enableSmartNotifications,
        'encryptedBackup': enableEncryptedBackup,
        'localLlm': enableLocalLlm,
        'offlineSpeech': enableOfflineSpeech,
      };

  static bool get hasRiskyPlatformFeatureEnabled =>
      enableVoiceInput ||
      enableVoiceResponse ||
      enableCalendar ||
      enablePdfExport ||
      enableShareFiles ||
      enableSmartNotifications;
}
