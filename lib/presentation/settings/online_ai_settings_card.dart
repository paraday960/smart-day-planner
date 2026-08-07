import 'package:flutter/material.dart';

import '../../services/online_ai_config.dart';

/// کارت تنظیمات «هوش مصنوعی آنلاین رایگان».
///
/// کاربر یک کلید رایگان (هزینهٔ صفر) از Google Gemini یا Groq وارد می‌کند تا
/// دستیار به جای موتور قانون‌محور، پاسخ‌های هوشمند آنلاین بدهد. بدون کلید،
/// برنامه به‌طور عادی با موتور قانون‌محور کار می‌کند.
class OnlineAiSettingsCard extends StatefulWidget {
  const OnlineAiSettingsCard({super.key});

  @override
  State<OnlineAiSettingsCard> createState() => _OnlineAiSettingsCardState();
}

class _OnlineAiSettingsCardState extends State<OnlineAiSettingsCard> {
  final TextEditingController _keyController = TextEditingController();
  String _provider = OnlineAiConfig.providerGemini;
  bool _showKey = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = OnlineAiConfig.instance;
    await cfg.load();
    if (!mounted) return;
    setState(() {
      _keyController.text = cfg.apiKey;
      _provider = cfg.provider;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await OnlineAiConfig.instance.set(_keyController.text, provider: _provider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('هوش مصنوعی آنلاین ذخیره شد ✅')),
    );
  }

  Future<void> _clear() async {
    setState(() {
      _keyController.clear();
    });
    await OnlineAiConfig.instance.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کلید حذف شد؛ دستیار با موتور قانون‌محور کار می‌کند.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text('هوش مصنوعی آنلاین رایگان'),
              subtitle: Text(
                'دستیار به‌جای موتور قانون‌محور، پاسخ‌های هوشمند و آنلاین می‌دهد. '
                'کلید رایگان (هزینهٔ صفر) وارد کنید. بدون کلید، برنامه عادی کار می‌کند.',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: 'سرویس هوش مصنوعی',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: OnlineAiConfig.providerGemini,
                  child: Text('Google Gemini'),
                ),
                DropdownMenuItem(
                  value: OnlineAiConfig.providerGroq,
                  child: Text('Groq'),
                ),
                DropdownMenuItem(
                  value: OnlineAiConfig.providerDeepseek,
                  child: Text('DeepSeek (از ایران در دسترس 🇮🇷)'),
                ),
                DropdownMenuItem(
                  value: OnlineAiConfig.providerGapgpt,
                  child: Text('GapGPT (ایرانی - بدون VPN)'),
                ),
                DropdownMenuItem(
                  value: OnlineAiConfig.providerMistral,
                  child: Text('Mistral (رایگان - ریت‌لایمیت)'),
                ),
              ],
              onChanged: _loaded
                  ? (v) => setState(() => _provider = v ?? _provider)
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyController,
              obscureText: !_showKey,
              enabled: _loaded && !_saving,
              decoration: InputDecoration(
                labelText: 'کلید API رایگان',
                hintText: 'AIza...  یا  gsk_...  یا  sk-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ProviderHelp(provider: _provider),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _loaded && !_saving ? _save : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره'),
                ),
                if (OnlineAiConfig.instance.hasKey)
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف کلید'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderHelp extends StatelessWidget {
  const _ProviderHelp({required this.provider});
  final String provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (steps, url) = _guideFor(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'راهنمای گرفتن کلید رایگان (هزینه صفر):',
          style: theme.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        for (final s in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(s, style: theme.textTheme.bodySmall),
          ),
        SelectableText(
          url,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      ],
    );
  }

  (List<String>, String) _guideFor(String p) {
    switch (p) {
      case OnlineAiConfig.providerGroq:
        return (
          [
            '۱. به console.groq.com برو و با حساب گوگل وارد شو.',
            '۲. در بخش API Keys یک کلید رایگان بساز.',
            '۳. کلید (شبیه gsk_...) را در بالا کپی کن.',
          ],
          'https://console.groq.com/'
        );
      case OnlineAiConfig.providerMistral:
        return (
          [
            '۱. به console.mistral.ai برو و با ایمیل ثبت‌نام کن (رایگان).',
            '۲. پلن رایگان «Free Experiment» را انتخاب کن.',
            '۳. در بخش API Keys یک کلید بساز (بدون کارت اعتباری).',
            '۴. کلید (شبیه ...) را در بالا کپی کن.',
          ],
          'https://console.mistral.ai/'
        );
      case OnlineAiConfig.providerDeepseek:
        return (
          [
            '۱. به platform.deepseek.com برو و ثبت‌نام کن (بدون VPN، از ایران در دسترس).',
            '۲. در بخش API Keys یک کلید بساز (شارژ اولیه رایگان می‌گیری).',
            '۳. کلید (شبیه sk-...) را در بالا کپی کن.',
          ],
          'https://platform.deepseek.com/'
        );
      case OnlineAiConfig.providerGapgpt:
        return (
          [
            '۱. به gapgpt.app برو و ثبت‌نام کن (سرویس ایرانی، بدون VPN).',
            '۲. یک کلید API رایگان بگیر.',
            '۳. کلید را در بالا کپی کن.',
          ],
          'https://gapgpt.app/'
        );
      case OnlineAiConfig.providerGemini:
      default:
        return (
          [
            '۱. به ai.google.dev برو و با حساب گوگل وارد شو.',
            '۲. روی Get an API key بزن و یک کلید رایگان بساز.',
            '۳. کلید (شبیه AIza...) را در بالا کپی کن.',
          ],
          'https://ai.google.dev/'
        );
    }
  }
}
