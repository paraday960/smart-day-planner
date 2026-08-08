import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_providers.dart';
import 'app/app_theme.dart';
import 'app/feature_flags.dart';
import 'app/smart_day_planner_root.dart';
import 'services/allocation_repository.dart';
import 'services/availability_repository.dart';
import 'services/category_budget_repository.dart';
import 'services/conversation_memory_service.dart';
import 'services/debt_repository.dart';
import 'services/finance_repository.dart';
import 'services/goal_repository.dart';
import 'services/llama_asset_installer.dart';
import 'services/llama_backend.dart' show getAppDocumentsDirectory;
import 'services/notification_service.dart';
import 'services/online_ai_config.dart';
import 'services/planned_expense_repository.dart';
import 'services/security_service.dart';
import 'services/local_assistant_memory.dart';
import 'services/smart_planner_agent.dart';
import 'services/task_repository.dart';
import 'services/voice_response_service.dart';
import 'services/vosk_asset_installer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── مدیریت سراسری خطا (به‌جای کرش بی‌صدا) ──────────────────────
  // هر خطای ناخواسته‌ای در UI یا ایزولهٔ اصلی لاگ می‌شود و برنامه
  // به کار خود ادامه می‌دهد (به‌جای صفحهٔ سفید یا کرش ناگهانی).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(_logError(details.exception, details.stack));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(_logError(error, stack));
    return true; // خطا را «مدیریت‌شده» اعلام کن تا اپ بسته نشود.
  };

  // استارتاپ داخل یک zone خطاگیر؛ هر خطای async سرگردانی هم ثبت می‌شود.
  await runZonedGuarded(_bootstrap, _logError);
}

/// استارتاپ مقاوم: اگر هر یک از مخزن‌ها یا سرویس‌ها خطا بدهد، فقط همان
/// بخش نادیده گرفته می‌شود و بقیهٔ اپ بالا می‌آید — نه صفحهٔ سفید.
Future<void> _bootstrap() async {
  final repository = TaskRepository();
  final financeRepository = FinanceRepository();
  final goalRepository = GoalRepository();
  final plannedExpenseRepository = PlannedExpenseRepository();
  final debtRepository = DebtRepository();
  final allocationRepository = AllocationRepository();
  final categoryBudgetRepository = CategoryBudgetRepository();
  final availabilityRepository = AvailabilityRepository();
  final conversationMemoryService = ConversationMemoryService();
  final notificationService = NotificationService.instance;
  final voiceResponseService = VoiceResponseService.instance;
  final securityService = SecurityService.instance;

  // بارگذاری تنظیمات هوش مصنوعی آنلاین (کلید رایگان کاربر)
  await OnlineAiConfig.instance.load();

  // بارگذاری حافظهٔ یادگیری سناریوهای دستیار (برای اجرای محلی بدون هوش آنلاین)
  await SmartScenarioMemory.instance.load();
  await LocalAssistantMemory.instance.load();

  // بارگذاری موازی برای استارت سریع‌تر (قبلاً سریال 10+ await بود)
  // Repository ها مستقل هستند و می‌توانند همزمان load شوند.
  // هر خطا جداگانه مدیریت می‌شود تا یک مخزنِ خراب کل اپ را نشکند.
  await Future.wait([
    _safeLoad('tasks', repository.load),
    _safeLoad('finance', financeRepository.load),
    _safeLoad('goals', goalRepository.load),
    _safeLoad('plannedExpenses', plannedExpenseRepository.load),
    _safeLoad('debts', debtRepository.load),
    _safeLoad('allocations', allocationRepository.load),
    _safeLoad('categoryBudgets', categoryBudgetRepository.load),
    _safeLoad('availability', availabilityRepository.load),
    _safeLoad('conversationMemory', conversationMemoryService.load),
    _safeLoad('security', securityService.load),
  ]);

  // سرویس‌های پلتفرمی هم می‌توانند موازی initialize شوند
  await Future.wait([
    _safeLoad('notifications', notificationService.initialize),
    _safeLoad('voiceResponse', voiceResponseService.initialize),
  ]);

  // نصب مدل‌های آفلاین (در صورت فعال بودن) به‌صورت موازی و با مدیریت خطا
  final List<Future<void>> assetInstallers = [];
  if (FeatureFlags.enableLocalLlm) {
    assetInstallers.add(
      const LlamaAssetInstaller().installIfNeeded().catchError((_) {
        // نبود مدل مشکلی نیست؛ دستیار به موتور قانون‌محور برمی‌گردد.
        return null;
      }),
    );
  }
  if (FeatureFlags.enableOfflineSpeech) {
    assetInstallers.add(
      const VoskAssetInstaller().installIfNeeded().catchError((_) {
        // نبود مدل مشکلی نیست؛ لایهٔ صوتی به سرویس آنلاین گوشی برمی‌گردد.
        return null;
      }),
    );
  }
  if (assetInstallers.isNotEmpty) {
    await Future.wait(assetInstallers);
  }

  runApp(
    ProviderScope(
      overrides: buildAppOverrides(
        taskRepository: repository,
        financeRepository: financeRepository,
        goalRepository: goalRepository,
        plannedExpenseRepository: plannedExpenseRepository,
        debtRepository: debtRepository,
        allocationRepository: allocationRepository,
        categoryBudgetRepository: categoryBudgetRepository,
        availabilityRepository: availabilityRepository,
        conversationMemoryService: conversationMemoryService,
        notificationService: notificationService,
        voiceResponseService: voiceResponseService,
        securityService: securityService,
      ),
      child: const SmartDayPlannerApp(),
    ),
  );
}

/// اجرای امن یک بارگذاری: خطا را لاگ می‌کند و اجازه می‌دهد بقیهٔ
/// استارتاپ ادامه یابد (به‌جای صفحهٔ سفید در صورت خرابی یکی از بخش‌ها).
Future<void> _safeLoad(String name, Future<void> Function() loader) async {
  try {
    await loader();
  } catch (e, s) {
    debugPrint('خطا در بارگذاری «$name»: $e');
    await _logError(e, s);
  }
}

/// ثبت خطا در کنسول + فایل error_log.txt در دایرکتوری اسناد
/// (گزینهٔ سبک crash log برای نسخهٔ بدون سرویس آنلاین).
Future<void> _logError(Object error, StackTrace? stack) async {
  debugPrint('SmartDayPlannerError: $error\n$stack');
  try {
    final dir = Directory(await getAppDocumentsDirectory());
    final file = File('${dir.path}/error_log.txt');
    final entry = '${DateTime.now().toIso8601String()}\n$error\n$stack\n'
        '----------------------------------------\n';
    await file.writeAsString(entry, mode: FileMode.append, flush: true);
  } catch (_) {
    // لاگ فایلی در دسترس نبود؛ debugPrint بالا کافی است.
  }
}

class SmartDayPlannerApp extends StatelessWidget {
  const SmartDayPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دستیار روزانه هوشمند ایرانی',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.theme,
      home: const SmartDayPlannerRoot(),
    );
  }
}
