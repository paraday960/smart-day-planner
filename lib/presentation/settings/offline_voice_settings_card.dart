import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/voice_response_service.dart';

/// کارت تنظیمات «صدای فارسی آفلاین» (Piper).
///
/// وقتی موتور گفتار سیستم فارسی درست صحبت نمی‌کند (مثل «ماینس‌ماینس» یا
/// انگلیسی)، کاربر می‌تواند این گزینه را روشن کند تا برنامه مدل فارسی Piper
/// را دانلود و کاملاً آفلاین فارسی صحبت کند.
class OfflineVoiceSettingsCard extends StatefulWidget {
  const OfflineVoiceSettingsCard({super.key});

  @override
  State<OfflineVoiceSettingsCard> createState() =>
      _OfflineVoiceSettingsCardState();
}

class _OfflineVoiceSettingsCardState extends State<OfflineVoiceSettingsCard> {
  bool _forcePiper = false;
  bool _downloading = false;
  bool _installed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = VoiceResponseService.instance;
    // از initialize استفاده نمی‌کنیم چون در محیط تست/بدون پلاگین ممکن است
    // بلاک شود. فقط مقدار ذخیره‌شدهٔ forcePiper را از SharedPreferences می‌خوانیم.
    try {
      final prefs = await SharedPreferences.getInstance();
      _forcePiper = prefs.getBool('smart_day_planner.voice_response.force_piper') ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _installed = service.offlineInstalled;
      _downloading = service.offlineChecking;
    });
  }

  Future<void> _toggle(bool value) async {
    final service = VoiceResponseService.instance;
    setState(() {
      _forcePiper = value;
      if (value) _downloading = true;
    });
    await service.setForcePiper(value);
    if (value) {
      // منتظر پایان دانلود بمان (بدون بلاک UI؛ فقط برای به‌روزرسانی وضعیت).
      while (true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final stillChecking = VoiceResponseService.instance.offlineChecking;
        if (!mounted) break;
        setState(() {
          _downloading = stillChecking;
          _installed = VoiceResponseService.instance.offlineInstalled;
        });
        if (!stillChecking) break;
      }
    }
  }

  Future<void> _testPiper() async {
    final service = VoiceResponseService.instance;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('در حال تست صدای آفلاین فارسی...')),
    );
    try {
      await service.testPiperVoice();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تست صدا انجام شد ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تست صدا ناموفق بود: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _downloading
        ? 'در حال دانلود مدل فارسی (~64MB)...'
        : _installed
            ? 'مدل فارسی آفلاین نصب شده ✅'
            : 'هنوز دانلود نشده است.';

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.record_voice_over_outlined),
              title: Text('صدای فارسی آفلاین'),
              subtitle: Text(
                'اگر صدای دستیار درست فارسی نمی‌گوید (مثلاً «ماینس‌ماینس» یا '
                'انگلیسی)، این گزینه را روشن کن تا برنامه مدل فارسی Piper را '
                'دانلود کند و کاملاً آفلاین فارسی صحبت کند.',
              ),
            ),
            SwitchListTile(
              value: _forcePiper,
              onChanged: _toggle,
              contentPadding: EdgeInsets.zero,
              title: const Text('فعال‌سازی صدای آفلاین Piper'),
              subtitle: Text(statusText),
            ),
            if (_installed || _downloading) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _downloading ? null : _testPiper,
                icon: const Icon(Icons.volume_up_outlined),
                label: Text(_downloading ? 'در حال دانلود...' : 'تست صدای آفلاین'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
