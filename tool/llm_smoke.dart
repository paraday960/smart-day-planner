// تست زندهٔ LLM محلی — اجرای واقعی مدل GGUF روی llama.cpp.
//
// نحوهٔ استفاده (بعد از ساخت libllama.so و دانلود مدل):
//   dart run tool/llm_smoke.dart \
//     --model=/path/to/qwen2.5-0.5b-instruct-q4_k_m.gguf \
//     --lib=/path/to/libllama.so
//
// نکته: اگر libllama.so به متغیر محیطی LD_LIBRARY_PATH اضافه شده باشد
// می‌توانید --lib را حذف کنید.
import 'dart:io';

import 'package:smart_day_planner/services/llama_backend.dart';

Future<void> main(List<String> args) async {
  String? modelPath;
  String? libPath;

  for (final arg in args) {
    if (arg.startsWith('--model=')) modelPath = arg.substring(8);
    if (arg.startsWith('--lib=')) libPath = arg.substring(6);
  }

  final envModel = Platform.environment['LLM_MODEL_PATH'];
  final envLib = Platform.environment['LLM_LIB_PATH'];
  modelPath ??= envModel;
  libPath ??= envLib;

  if (modelPath == null) {
    stderr.writeln('مسیر مدل را بده: --model=/path/to/model.gguf');
    exitCode = 2;
    return;
  }

  stdout.writeln('=== تست LLM محلی ===');
  stdout.writeln('مدل: $modelPath');
  stdout.writeln('کتابخانه: ${libPath ?? "libllama.so (جستجوی سیستمی)"}');

  final backend = LlamaCppBackend(
    enabled: true,
    modelPath: modelPath,
    libraryPath: libPath,
    maxTokens: 160,
    contextSize: 512,
    timeout: const Duration(minutes: 3),
  );

  stdout.writeln('\n[۱] بررسی دسترسی...');
  final ready = await backend.available;
  if (!ready) {
    stderr.writeln('❌ مدل یا کتابخانه در دسترس نیست.');
    exitCode = 1;
    return;
  }
  stdout.writeln('✅ در دسترس است.');

  const prompts = [
    'سلام! خوبی؟ حالت چطوره؟',
    'الان سه تا کار دارم: تماس با مشتری (خیلی مهم)، ثبت گزارش، خرید. بهترین کار بعدی چیه؟',
    'می‌خوام امروز ۴ ساعت کار درآمدزا بکنم. چطور برنامه بریزم؟',
  ];

  var i = 1;
  for (final prompt in prompts) {
    stdout.writeln('\n[${i + 1}] پرسش: $prompt');
    final sw = Stopwatch()..start();
    try {
      final answer = await backend.generate(prompt);
      sw.stop();
      stdout.writeln('پاسخ (${sw.elapsed.inSeconds} ثانیه):');
      stdout.writeln('────────────────────────────');
      stdout.writeln(answer);
      stdout.writeln('────────────────────────────');
      if (answer.trim().isEmpty) {
        stderr.writeln('⚠️ پاسخ خالی بود.');
        exitCode = 1;
      }
    } catch (e) {
      sw.stop();
      stderr.writeln('❌ خطا (${sw.elapsed.inSeconds} ثانیه): $e');
      exitCode = 1;
    }
    i++;
  }

  stdout.writeln('\n=== پایان تست ===');
  await backend.dispose();
}
