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
  // Repository ها مستقل هستند و می‌توانند همزمان load شوند
  await Future.wait([
    repository.load(),
    financeRepository.load(),
    goalRepository.load(),
    plannedExpenseRepository.load(),
    debtRepository.load(),
    allocationRepository.load(),
    categoryBudgetRepository.load(),
    availabilityRepository.load(),
    conversationMemoryService.load(),
    securityService.load(),
  ]);

  // سرویس‌های پلتفرمی هم می‌توانند موازی initialize شوند
  await Future.wait([
    notificationService.initialize(),
    voiceResponseService.initialize(),
  ]);

  // نصب مدل‌های آفلاین (در صورت فعال بودن) به‌صورت موازی و با مدیریت خطا
  final List<Future<void>> assetInstallers = [];
  if (FeatureFlags.enableLocalLlm) {
    assetInstallers.add(
      const LlamaAssetInstaller().installIfNeeded().catchError((_) {
        // نبود مدل مشکلی نیست؛ دستیار به موتور قانون‌محور برمی‌گردد.
      }),
    );
  }
  if (FeatureFlags.enableOfflineSpeech) {
    assetInstallers.add(
      const VoskAssetInstaller().installIfNeeded().catchError((_) {
        // نبود مدل مشکلی نیست؛ لایهٔ صوتی به سرویس آنلاین گوشی برمی‌گردد.
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
