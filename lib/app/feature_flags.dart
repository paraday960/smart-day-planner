class FeatureFlags {
  const FeatureFlags._();

  /// برای ساخت نسخه پایدار اولیه می‌توان قابلیت‌های پرریسک را با dart-define خاموش کرد.
  /// مثال:
  /// flutter run --dart-define=ENABLE_CALENDAR=false
  static const enableVoiceInput = bool.fromEnvironment('ENABLE_VOICE_INPUT', defaultValue: true);
  static const enableVoiceResponse = bool.fromEnvironment('ENABLE_VOICE_RESPONSE', defaultValue: true);
  static const enableCalendar = bool.fromEnvironment('ENABLE_CALENDAR', defaultValue: true);
  static const enablePdfExport = bool.fromEnvironment('ENABLE_PDF_EXPORT', defaultValue: true);
  static const enableShareFiles = bool.fromEnvironment('ENABLE_SHARE_FILES', defaultValue: true);
  static const enableSmartNotifications = bool.fromEnvironment('ENABLE_SMART_NOTIFICATIONS', defaultValue: true);
  static const enableEncryptedBackup = bool.fromEnvironment('ENABLE_ENCRYPTED_BACKUP', defaultValue: true);

  static Map<String, bool> asMap() => {
        'voiceInput': enableVoiceInput,
        'voiceResponse': enableVoiceResponse,
        'calendar': enableCalendar,
        'pdfExport': enablePdfExport,
        'shareFiles': enableShareFiles,
        'smartNotifications': enableSmartNotifications,
        'encryptedBackup': enableEncryptedBackup,
      };

  static bool get hasRiskyPlatformFeatureEnabled =>
      enableVoiceInput || enableVoiceResponse || enableCalendar || enablePdfExport || enableShareFiles || enableSmartNotifications;
}
