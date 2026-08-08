import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'llama_backend.dart';
import 'online_ai_config.dart';

/// خطای مربوط به عدم دسترسی به هوش مصنوعی آنلاین.
class OnlineAiNotAvailableException implements Exception {
  const OnlineAiNotAvailableException([this.message = 'هوش مصنوعی آنلاین در دسترس نیست']);
  final String message;

  @override
  String toString() => message;
}

/// بک‌اند هوش مصنوعی آنلاین رایگان — بدون نیاز به مدل محلی سنگین.
///
/// از API های سازگار با OpenAI استفاده می‌کند:
/// - گوگل Gemini (پیش‌فرض؛ فارسی قوی و سهمیهٔ رایگان سخاوتمندانه)
/// - Groq (خیلی سریع)
/// - DeepSeek (چینی؛ از داخل ایران در دسترس و ارزان)
/// - GapGPT (ایرانی؛ بدون VPN، کلید رایگان)
///
/// کلید از این منابع خوانده می‌شود (به ترتیب اولویت):
/// 1. `--dart-define=ONLINE_AI_API_KEY=...` هنگام ساخت
/// 2. تابع تأمین‌کننده (برای تست)
/// 3. تنظیمات برنامه ([OnlineAiConfig])
class OnlineLlmBackend implements LlmBackend {
  OnlineLlmBackend({
    OnlineAiConfig? config,
    String? Function()? keyProvider,
    String? apiKeyOverride,
    Duration timeout = const Duration(seconds: 30),
  })  : _config = config ?? OnlineAiConfig.instance,
        _keyProvider = keyProvider,
        _apiKeyOverride = apiKeyOverride,
        _timeout = timeout;

  final OnlineAiConfig _config;
  final String? Function()? _keyProvider;
  final String? _apiKeyOverride;
  final Duration _timeout;

  static const String envApiKey = String.fromEnvironment('ONLINE_AI_API_KEY');

  String? get _apiKey {
    final override = _apiKeyOverride;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    if (envApiKey.isNotEmpty) return envApiKey;
    final provider = _keyProvider;
    if (provider != null) {
      final k = provider();
      if (k != null && k.isNotEmpty) return k;
    }
    if (_config.hasKey) return _config.apiKey;
    return null;
  }

  @override
  Future<bool> get available async => _apiKey != null;

  String get _systemPrompt =>
      'تو یک دستیار برنامه‌ریزی روزانهٔ هوشمند برای کاربر ایرانی هستی. '
      'همیشه به فارسی، کوتاه، دوستانه و عملی پاسخ بده. '
      'اگر سؤال دربارهٔ برنامه‌ریزی، امور مالی، بدهی، هدف یا عادت است راهنمایی کاربردی بده. '
      'در پایان، اگر لازم بود، اقدام بعدی را در یک جمله خلاصه کن.';

  @override
  Future<String> generate(String prompt) async {
    final key = _apiKey;
    if (key == null) {
      throw const OnlineAiNotAvailableException(
          'کلید هوش مصنوعی آنلاین تنظیم نشده است');
    }

    final endpoint = _endpointFor(_config.provider);
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.postUrl(Uri.parse(endpoint.url));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $key');
      final body = jsonEncode({
        'model': endpoint.model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.5,
        'max_tokens': 500,
      });
      request.add(utf8.encode(body));

      final response = await request.close().timeout(_timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      if (response.statusCode != 200) {
        // جزئیات خطای سرویس فقط برای لاگ — به کاربر فقط کد وضعیت نمایش
        // داده می‌شود تا پیام‌های فنی گیج‌کننده به UI نروند.
        debugPrint(
            'OnlineLlmBackend: خطای سرویس ${response.statusCode}: ${_trim(text)}');
        throw OnlineAiNotAvailableException('خطای سرویس (${response.statusCode})');
      }

      final data = jsonDecode(text) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const OnlineAiNotAvailableException('پاسخ نامعتبر از سرویس');
      }
      final message =
          (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const OnlineAiNotAvailableException('پاسخ خالی از سرویس');
      }
      return content.trim();
    } on OnlineAiNotAvailableException {
      rethrow;
    } on TimeoutException {
      throw const OnlineAiNotAvailableException(
          'اتصال به هوش مصنوعی آنلاین به‌موقع جواب نداد');
    } catch (e) {
      throw OnlineAiNotAvailableException('خطا در اتصال آنلاین: ${e.toString()}');
    } finally {
      client.close(force: true);
    }
  }

  String _trim(String s) {
    final t = s.trim();
    return t.length > 160 ? t.substring(0, 160) : t;
  }

  _Endpoint _endpointFor(String provider) {
    switch (provider) {
      case OnlineAiConfig.providerGroq:
        return const _Endpoint(
          url: 'https://api.groq.com/openai/v1/chat/completions',
          model: 'llama-3.3-70b-versatile',
        );
      case OnlineAiConfig.providerDeepseek:
        return const _Endpoint(
          url: 'https://api.deepseek.com/v1/chat/completions',
          model: 'deepseek-chat',
        );
      case OnlineAiConfig.providerGapgpt:
        return const _Endpoint(
          url: 'https://gapgpt.app/api/v1/chat/completions',
          model: 'gpt-4',
        );
      case OnlineAiConfig.providerMistral:
        return const _Endpoint(
          url: 'https://api.mistral.ai/v1/chat/completions',
          model: 'mistral-small-latest',
        );
      case OnlineAiConfig.providerGemini:
      default:
        return const _Endpoint(
          url:
              'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
          model: 'gemini-2.0-flash',
        );
    }
  }
}

class _Endpoint {
  const _Endpoint({required this.url, required this.model});
  final String url;
  final String model;
}

/// بک‌اند اولویت‌دار — به ترتیب تلاش می‌کند تا اولین پاسخ موفق برگردد.
///
/// برای ترتیب «اول آنلاین، بعد محلی، بعد قانون‌محور» به کار می‌رود.
class PriorityLlmBackend implements LlmBackend {
  PriorityLlmBackend(
    List<LlmBackend> backends, {
    Duration timeout = const Duration(seconds: 35),
    Duration fallbackTimeout = const Duration(seconds: 8),
  })  : _backends = List.unmodifiable(backends),
        _timeout = timeout,
        _fallbackTimeout = fallbackTimeout;

  final List<LlmBackend> _backends;
  final Duration _timeout;

  /// بک‌اندهای جایگزین مهلت کوتاه‌تری دارند تا کاربر در بدترین حالت
  /// (N بک‌اند × timeout کامل) مدت طولانی منتظر نماند.
  final Duration _fallbackTimeout;

  @override
  Future<bool> get available async {
    for (final b in _backends) {
      try {
        if (await b.available) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<String> generate(String prompt) async {
    for (var i = 0; i < _backends.length; i++) {
      final b = _backends[i];
      try {
        if (await b.available) {
          final timeout = i == 0 ? _timeout : _fallbackTimeout;
          return await b.generate(prompt).timeout(timeout);
        }
      } on TimeoutException {
        // به بک‌اند بعدی برو
      } catch (_) {
        // به بک‌اند بعدی برو
      }
    }
    throw const OnlineAiNotAvailableException('هیچ بک‌اندی در دسترس نیست');
  }
}
