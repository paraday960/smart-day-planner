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
import 'services/planned_expense_repository.dart';
import 'services/security_service.dart';
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

  await repository.load();
  await financeRepository.load();
  await goalRepository.load();
  await plannedExpenseRepository.load();
  await debtRepository.load();
  await allocationRepository.load();
  await categoryBudgetRepository.load();
  await availabilityRepository.load();
  await conversationMemoryService.load();
  await securityService.load();
  await notificationService.initialize();
  await voiceResponseService.initialize();

  // اگر LLM محلی فعال باشد و مدل به‌عنوان asset باندل شده باشد،
  // یک‌بار آن را به دایرکتوری اسناد کپی می‌کنیم.
  if (FeatureFlags.enableLocalLlm) {
    try {
      await const LlamaAssetInstaller().installIfNeeded();
    } catch (_) {
      // نبود مدل مشکلی نیست؛ دستیار به موتور قانون‌محور برمی‌گردد.
    }
  }

  // اگر تشخیص گفتار آفلاین (Vosk) فعال باشد و مدل فارسی به‌عنوان asset
  // باندل شده باشد، یک‌بار آن را به دایرکتوری اسناد کپی می‌کنیم تا
  // VoskModelLocator پیدایش کند و فرمان صوتی واقعاً بدون اینترنت کار کند.
  if (FeatureFlags.enableOfflineSpeech) {
    try {
      await const VoskAssetInstaller().installIfNeeded();
    } catch (_) {
      // نبود مدل مشکلی نیست؛ لایهٔ صوتی به سرویس آنلاین گوشی برمی‌گردد.
    }
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
