import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app_config.dart';
import 'learning_dashboard_screen.dart';
import 'assistant_trace_screen.dart';
import 'offline_voice_settings_card.dart';
import 'online_ai_settings_card.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key,
    required this.onSetPin,
    required this.onDisablePin,
    required this.onLockNow,
    required this.onCreateBackup,
    required this.onShareBackupFile,
    required this.onRestoreBackup,
    required this.onExportTasksCsv,
    required this.onExportFinanceCsv,
    required this.onMonthlyReport,
    required this.onConfigureAvailability,
    required this.onSmartAlertsPreview,
    required this.onScheduleSmartAlerts,
    required this.onCalendarPreview,
    required this.onShareRealPdfReport,
    required this.onPrintablePdfReport,
  });

  final VoidCallback onSetPin;
  final VoidCallback onDisablePin;
  final VoidCallback onLockNow;
  final VoidCallback onCreateBackup;
  final VoidCallback onShareBackupFile;
  final VoidCallback onRestoreBackup;
  final VoidCallback onExportTasksCsv;
  final VoidCallback onExportFinanceCsv;
  final VoidCallback onMonthlyReport;
  final VoidCallback onConfigureAvailability;
  final VoidCallback onSmartAlertsPreview;
  final VoidCallback onScheduleSmartAlerts;
  final VoidCallback onCalendarPreview;
  final VoidCallback onShareRealPdfReport;
  final VoidCallback onPrintablePdfReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityService = ref.watch(securityServiceProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('تنظیمات حرفه‌ای', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const OnlineAiSettingsCard(),
        const SizedBox(height: 12),
        const OfflineVoiceSettingsCard(),
        const SizedBox(height: 12),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('امنیت و قفل برنامه'),
                  subtitle: Text(securityService.pinEnabled
                      ? 'قفل با رمز فعال است. (PBKDF2 امن - ارتقا یافته)'
                      : 'قفل برنامه فعال نیست. پیشنهاد: فعال کنید.'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(onPressed: onSetPin, icon: const Icon(Icons.password), label: const Text('تنظیم/تغییر رمز')),
                    if (securityService.pinEnabled)
                      OutlinedButton.icon(onPressed: onDisablePin, icon: const Icon(Icons.lock_open), label: const Text('حذف رمز')),
                    if (securityService.pinEnabled)
                      OutlinedButton.icon(onPressed: onLockNow, icon: const Icon(Icons.lock), label: const Text('قفل فوری')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.enhanced_encryption_outlined),
                  title: Text('بکاپ رمزنگاری‌شده'),
                  subtitle: Text('بکاپ با AES-GCM + PBKDF2 (200k تکرار) رمزنگاری می‌شود - امن و احرازشده.'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(onPressed: onCreateBackup, icon: const Icon(Icons.backup_outlined), label: const Text('ساخت بکاپ')),
                    OutlinedButton.icon(onPressed: onShareBackupFile, icon: const Icon(Icons.ios_share), label: const Text('اشتراک فایل بکاپ')),
                    OutlinedButton.icon(onPressed: onRestoreBackup, icon: const Icon(Icons.restore), label: const Text('بازیابی بکاپ')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('خروجی و گزارش'),
                  subtitle: Text('خروجی‌ها قابل کپی هستند و می‌توانی در فایل ذخیره کنی.'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: onExportTasksCsv, icon: const Icon(Icons.table_chart_outlined), label: const Text('CSV کارها')),
                    OutlinedButton.icon(onPressed: onExportFinanceCsv, icon: const Icon(Icons.receipt_long_outlined), label: const Text('CSV مالی')),
                    FilledButton.tonal(onPressed: onMonthlyReport, child: const Text('گزارش ماه شمسی')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.event_available_outlined),
                  title: Text('تقویم، هشدار هوشمند و گزارش'),
                  subtitle: Text('پنجره کاری روزانه، هشدارهای ریسک و گزارش آماده PDF.'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: onConfigureAvailability, icon: const Icon(Icons.schedule), label: const Text('تنظیم زمان آزاد')),
                    OutlinedButton.icon(onPressed: onCalendarPreview, icon: const Icon(Icons.calendar_month_outlined), label: const Text('تقویم گوشی')),
                    OutlinedButton.icon(onPressed: onSmartAlertsPreview, icon: const Icon(Icons.notifications_active_outlined), label: const Text('هشدارهای هوشمند')),
                    OutlinedButton.icon(onPressed: onScheduleSmartAlerts, icon: const Icon(Icons.alarm_add_outlined), label: const Text('زمان‌بندی هشدار')),
                    FilledButton.tonal(onPressed: onPrintablePdfReport, child: const Text('HTML آماده PDF')),
                    FilledButton(onPressed: onShareRealPdfReport, child: const Text('PDF واقعی و اشتراک‌گذاری')),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('مدیریت حافظه یادگیری 🧠'),
            subtitle: const Text('هر چی هوش محلی یاد گرفته: ویرایش/حذف، جستجو، صادرات/واردات — با امتیاز مهارت'),
            trailing: FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearningDashboardScreen())),
              child: const Text('باز کردن'),
            ),
          ),
        ),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.smart_toy_outlined),
                  title: Text('حالت دستیار خودکار هیبرید 🤖'),
                  subtitle: Text('تمام کارها توسط دستیار انجام می‌شود — فقط موارد حساس تایید می‌خواهد.'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✅ فعال: هیبرید هوشمند\n• فرمان‌های ساده → اجرای فوری بدون تایید\n• مبالغ بالا یا مبهم → دستیار می‌پرسد "تایید می‌کنی؟"\n• استارت سریع: بارگذاری موازی repoها (اصلاح 2026-08-07)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('ردپای دستیار (دیباگ)'),
                  subtitle: const Text('مشاهده و کپی مراحل پردازش درخواست‌ها'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AssistantTraceScreen(),
                    ),
                  ),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('حریم خصوصی و پشتیبانی'),
                ),
                Text(AppConfig.privacyMode),
                const SizedBox(height: 8),
                Text('نسخه: ${AppConfig.versionName} (${AppConfig.versionCode}) - ${AppConfig.packageName}'),
                const SizedBox(height: 4),
                if (AppConfig.supportEmail.isNotEmpty)
                  SelectableText('پشتیبانی: ${AppConfig.supportEmail}'),
                const SizedBox(height: 8),
                const Text('امنیت و قفل، بکاپ رمزنگاری‌شده (AES-GCM + PBKDF2)، خروجی و گزارش، تحلیل مالی، بودجه‌بندی و هشدارهای آینده‌نگر همگی روی همین گوشی و بدون سرور انجام می‌شوند.'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔒 اصلاحات امنیتی 2026-08-07:\n• PIN: SHA256 خام → PBKDF2 (100k) + salt + constant-time\n• بکاپ: AES-CBC بدون MAC → AES-GCM + PBKDF2 200k\n• استارت: سریال → موازی Future.wait\n• فرمان صوتی: nullable → required non-nullable',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
