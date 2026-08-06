class AppConfig {
  const AppConfig._();

  static const appNameFa = 'دستیار روزانه ایرانی';
  static const appNameEn = 'Smart Day Planner Iranian';

  /// باید با `applicationId` در `android/app/build.gradle.kts` هماهنگ باشد.
  static const packageName = 'ir.smartday.smart_day_planner';

  /// باید با `version` در `pubspec.yaml` هماهنگ باشد (نسخه و build).
  static const versionName = '1.0.0';
  static const versionCode = 1;

  /// ایمیل پشتیبانی — قبل از انتشار واقعی مقدار واقعی بگذارید.
  /// خالی یعنی هنوز اعلام نشده (در UI هم نمایش داده نمی‌شود).
  static const supportEmail = '';
  static const privacyMode = 'Local-first: اطلاعات اصلی روی گوشی کاربر ذخیره می‌شود.';
}
