import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';

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
                  subtitle: Text(securityService.pinEnabled ? 'قفل با رمز فعال است.' : 'قفل برنامه فعال نیست.'),
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
                  subtitle: Text('برای حفظ حریم خصوصی، بکاپ با رمز دلخواه کاربر رمزنگاری می‌شود.'),
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
                  title: Text('فاز ۸: تقویم، هشدار هوشمند و PDF'),
                  subtitle: Text('پنجره کاری روزانه، هشدارهای ریسک و گزارش HTML آماده PDF.'),
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
        const Card.outlined(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('فازهای حرفه‌ای‌سازی: امنیت، بکاپ، خروجی، تحلیل، بودجه‌بندی، گفت‌وگوی هوشمند، نمودار، محدودیت زمانی و هشدارهای آینده‌نگر.'),
          ),
        ),
      ],
    );
  }
}

