import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_providers.dart';
import '../app/app_theme.dart';
import '../app/feature_flags.dart';
import '../domain/services/notification_service_port.dart';
import '../domain/services/voice_response_port.dart';
import '../models/debt_item.dart';
import '../models/finance_transaction.dart';
import '../models/money_allocation.dart';
import '../models/planned_expense_goal.dart';
import '../models/task.dart';
import '../application/actions/report_actions_controller.dart';
import '../application/home/home_coordinator.dart';
import '../presentation/assistant/assistant_tab.dart';
import '../presentation/assistant/chat_message.dart';
import '../presentation/dashboard/dashboard_tab.dart';
import '../presentation/dialogs/backup_dialogs.dart';
import '../presentation/dialogs/common_dialogs.dart';
import '../presentation/dialogs/finance_dialogs.dart';
import '../presentation/dialogs/goal_dialogs.dart';
import '../presentation/dialogs/planning_dialogs.dart';
import '../presentation/dialogs/security_dialogs.dart';
import '../presentation/dialogs/task_dialogs.dart';
import '../presentation/finance/finance_tab.dart';
import '../presentation/settings/settings_tab.dart';
import '../presentation/tasks/tasks_tab.dart';
import '../services/allocation_repository.dart';
import '../services/availability_repository.dart';
import '../domain/services/calendar_service_port.dart';
import '../services/category_budget_repository.dart';
import '../services/conversation_memory_service.dart';
import '../services/debt_repository.dart';
import '../services/finance_repository.dart';
import '../services/goal_repository.dart';
import '../services/hybrid_local_assistant.dart';
import '../services/local_assistant.dart';
import '../services/online_ai_config.dart';
import '../domain/services/share_file_service_port.dart';
import '../services/planned_expense_repository.dart';
import '../services/security_service.dart';
import '../services/smart_notification_advisor.dart';
import '../services/smart_notification_scheduler.dart';
import '../services/task_repository.dart';
import '../application/home/assistant_coordinator.dart';
import '../application/home/task_flow_coordinator.dart';
import '../services/voice_input.dart';
import '../services/voice_nlu.dart';
// Refactor 2026-08-06: منطق دستیار به AssistantCoordinator و جریان کار به TaskFlowCoordinator منتقل شد
import '../services/voice_response_service.dart';
import '../utils/persian_format.dart';
import '../widgets/task_form_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ReportActionsController _reportActions;
  late final HomeCoordinator _homeCoordinator;
  final _notificationAdvisor = const SmartNotificationAdvisor();
  late final ShareFileServicePort _shareFileService;
  late final CalendarServicePort _calendarService;
  late final SmartNotificationScheduler _smartNotificationScheduler;
  late final LocalLlmAdapter _assistant;
  String _assistantStatusLabel = 'هوش قانونی (بدون LLM)';
  late final AssistantCoordinator _assistantCoordinator;
  late final TaskFlowCoordinator _taskFlowCoordinator;

  /// ورودی صدا — اگر فرمان صوتی غیرفعال باشد، مقدار پیش‌فرض امن می‌ماند.
  late VoiceInput _voiceInput = OnlineVoiceInput();
  final _assistantController = TextEditingController();

  /// گفتگوی چت دستیار.
  final List<ChatMessage> _chatMessages = [];
  bool _isTyping = false;

  String _lastVoiceText = '';
  String _voiceStatus =
      'برای فرمان صوتی، دکمه میکروفون را نگه دار و فارسی صحبت کن. تشخیص صدا می‌تواند از سرویس رایگان گوشی و اینترنت استفاده کند.';
  bool _speechReady = false;
  bool _isListening = false;
  double _soundLevel = 0;
  bool _voiceResponseEnabled = true;
  AssistantVoiceGender _assistantVoiceGender = AssistantVoiceGender.feminine;

  late final TaskRepository _repository;
  late final FinanceRepository _financeRepository;
  late final GoalRepository _goalRepository;
  late final PlannedExpenseRepository _plannedExpenseRepository;
  late final DebtRepository _debtRepository;
  late final AllocationRepository _allocationRepository;
  late final CategoryBudgetRepository _categoryBudgetRepository;
  late final AvailabilityRepository _availabilityRepository;
  late final ConversationMemoryService _conversationMemoryService;
  late final NotificationServicePort _notificationService;
  late final VoiceResponsePort _voiceResponseService;
  late final SecurityService _securityService;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(taskRepositoryProvider);
    _financeRepository = ref.read(financeRepositoryProvider);
    _goalRepository = ref.read(goalRepositoryProvider);
    _plannedExpenseRepository = ref.read(plannedExpenseRepositoryProvider);
    _debtRepository = ref.read(debtRepositoryProvider);
    _allocationRepository = ref.read(allocationRepositoryProvider);
    _categoryBudgetRepository = ref.read(categoryBudgetRepositoryProvider);
    _availabilityRepository = ref.read(availabilityRepositoryProvider);
    _conversationMemoryService = ref.read(conversationMemoryServiceProvider);
    _notificationService = ref.read(notificationServiceProvider);
    _voiceResponseService = ref.read(voiceResponseServiceProvider);
    _securityService = ref.read(securityServiceProvider);
    _reportActions = ref.read(reportActionsControllerProvider);
    _homeCoordinator = ref.read(homeCoordinatorProvider);
    _shareFileService = ref.read(shareFileServiceProvider);
    _calendarService = ref.read(calendarServiceProvider);
    final assistant = ref.read(assistantProvider);
    _assistant = assistant;
    _assistantStatusLabel = _buildAssistantStatusLabel(assistant);
    // وقتی کاربر کلید هوش آنلاین را در تنظیمات تغییر داد، برچسب را تازه کن.
    OnlineAiConfig.instance.version.addListener(_onOnlineAiConfigChanged);
    _smartNotificationScheduler =
        SmartNotificationScheduler(notificationService: _notificationService);
    _assistantCoordinator = AssistantCoordinator(
      voiceResponseService: _voiceResponseService,
      autonomousAgent: ref.read(autonomousAgentServiceProvider),
    );
    _taskFlowCoordinator = TaskFlowCoordinator(
      homeCoordinator: _homeCoordinator,
      taskRepository: _repository,
      financeRepository: _financeRepository,
    );
    _voiceResponseEnabled =
        FeatureFlags.enableVoiceResponse && _voiceResponseService.enabled;
    _assistantVoiceGender = _voiceResponseService.gender;
    if (FeatureFlags.enableVoiceInput) {
      _initVoiceInput();
    }
    _repository.addListener(_onRepositoryChanged);
    _financeRepository.addListener(_onRepositoryChanged);
    _goalRepository.addListener(_onRepositoryChanged);
    _plannedExpenseRepository.addListener(_onRepositoryChanged);
    _debtRepository.addListener(_onRepositoryChanged);
    _allocationRepository.addListener(_onRepositoryChanged);
    _categoryBudgetRepository.addListener(_onRepositoryChanged);
    _availabilityRepository.addListener(_onRepositoryChanged);
    _securityService.addListener(_onRepositoryChanged);
    _assistant.generate(prompt: '', tasks: _repository.tasks).then((value) {
      if (!mounted) return;
      setState(() {
        _chatMessages.add(ChatMessage(text: value, isUser: false));
      });
    });
  }

  void _onOnlineAiConfigChanged() {
    if (!mounted) return;
    setState(() {
      _assistantStatusLabel = _buildAssistantStatusLabel(_assistant);
    });
  }

  @override
  void dispose() {
    OnlineAiConfig.instance.version.removeListener(_onOnlineAiConfigChanged);
    _repository.removeListener(_onRepositoryChanged);
    _financeRepository.removeListener(_onRepositoryChanged);
    _goalRepository.removeListener(_onRepositoryChanged);
    _plannedExpenseRepository.removeListener(_onRepositoryChanged);
    _debtRepository.removeListener(_onRepositoryChanged);
    _allocationRepository.removeListener(_onRepositoryChanged);
    _categoryBudgetRepository.removeListener(_onRepositoryChanged);
    _availabilityRepository.removeListener(_onRepositoryChanged);
    _securityService.removeListener(_onRepositoryChanged);
    _voiceInput.cancel();
    _voiceResponseService.stop();
    _assistantController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    // محافظت: اگر widget در حال dispose/حذف است، setState نزن.
    // به‌علاوه، ری‌بیلد را به بعد از پایان فریم موکول می‌کنیم تا اگر در همین
    // لحظه دیالوگ/روتی در حال بسته‌شدن است، تداخلی با حذف آن پیش نیاید
    // (جلوگیری از خطای «_dependents.isEmpty» هنگام افزودن درآمد/هزینه).
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initVoiceInput() async {
    // انتخاب موتور: آفلاین (Vosk) اگر فعال و مدل موجود باشد، وگرنه سرویس گوشی.
    final input = await VoiceInputFactory.create();
    _voiceInput = input;

    final ready = await _voiceInput.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _voiceStatus = status);
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _voiceStatus = error;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _speechReady = ready;
      final engine = input.engineName;
      _voiceStatus = ready
          ? 'آماده است. دکمه میکروفون را نگه دار و فارسی بگو. (موتور: $engine)'
          : 'تشخیص صدا فعال نشد. دسترسی میکروفون و سرویس تشخیص گفتار گوشی را بررسی کن.';
    });
  }

  Future<void> _startVoiceCommand() async {
    if (!_isFeatureEnabled(FeatureFlags.enableVoiceInput, 'فرمان صوتی')) return;
    if (!_speechReady) await _initVoiceInput();
    if (!_speechReady || _voiceInput.isListening) return;

    setState(() {
      _isListening = true;
      _lastVoiceText = '';
      _voiceStatus = 'در حال گوش دادن... بعد از گفتن فرمان، دکمه را رها کن.';
    });

    await _voiceInput.start(
      onPartial: (text) {
        if (!mounted) return;
        setState(() => _lastVoiceText = text);
      },
      onSoundLevel: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
      onResult: (text) {
        if (!mounted) return;
        setState(() => _lastVoiceText = text);
      },
    );
  }

  Future<void> _stopVoiceCommand() async {
    if (!_voiceInput.isListening && !_isListening) return;
    await _voiceInput.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _soundLevel = 0;
      _voiceStatus = 'در حال اجرای فرمان...';
    });

    final spokenText = _lastVoiceText.trim();
    if (!mounted) return;
    setState(() {
      _voiceStatus =
          spokenText.isEmpty ? 'متنی تشخیص داده نشد.' : '🤖 در حال پردازش...';
    });
    if (spokenText.isEmpty) return;
    await _processUserRequest(spokenText);
    if (!mounted) return;
    setState(() {
      _voiceStatus = '🤖 انجام شد.';
    });
  }

  Future<void> _setVoiceResponseEnabled(bool value) async {
    if (!_isFeatureEnabled(FeatureFlags.enableVoiceResponse, 'پاسخ صوتی')) {
      return;
    }
    await _voiceResponseService.setEnabled(value);
    if (!mounted) return;
    setState(() => _voiceResponseEnabled = value);
  }

  Future<void> _setAssistantVoiceGender(AssistantVoiceGender gender) async {
    if (!_isFeatureEnabled(FeatureFlags.enableVoiceResponse, 'پاسخ صوتی')) {
      return;
    }
    await _voiceResponseService.setGender(gender);
    if (!mounted) return;
    setState(() => _assistantVoiceGender = gender);
    await _voiceResponseService.testVoice();
  }

  Future<void> _testAssistantVoice() async {
    if (!_isFeatureEnabled(FeatureFlags.enableVoiceResponse, 'پاسخ صوتی')) {
      return;
    }
    final sample = await _voiceResponseService.testVoice();
    if (!mounted) return;
    setState(() {
      _chatMessages.add(ChatMessage(text: '🔊 تست صدا: $sample', isUser: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F5FF),
        appBar: AppBar(
          title: const Text('دستیار روزانه هوشمند'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
                fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'دستیار'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'امروز'),
              Tab(icon: Icon(Icons.checklist), text: 'کارها'),
              Tab(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  text: 'حسابدار'),
              Tab(icon: Icon(Icons.settings_outlined), text: 'تنظیمات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AssistantTab(
              controller: _assistantController,
              messages: _chatMessages,
              isTyping: _isTyping,
              assistantStatusLabel: _assistantStatusLabel,
              speechReady: _speechReady,
              isListening: _isListening,
              lastVoiceText: _lastVoiceText,
              voiceStatus: _voiceStatus,
              soundLevel: _soundLevel,
              voiceResponseEnabled: _voiceResponseEnabled,
              assistantVoiceGender: _assistantVoiceGender,
              onAsk: _askAssistant,
              onVoiceDown: _startVoiceCommand,
              onVoiceUp: _stopVoiceCommand,
              onVoiceResponseEnabledChanged: _setVoiceResponseEnabled,
              onVoiceGenderChanged: _setAssistantVoiceGender,
              onTestVoice: _testAssistantVoice,
            ),
            DashboardTab(
              onEdit: _openTaskForm,
              onComplete: _completeTask,
            ),
            TasksTab(
              onEdit: _openTaskForm,
              onComplete: _completeTask,
              onReopen: _reopenTask,
              onDelete: _deleteTask,
              onTogglePin: (task) => _repository.togglePin(task.id),
            ),
            FinanceTab(
              onAddTransaction: _openTransactionDialog,
              onSetGoals: _openGoalsDialog,
              onAddPlannedExpense: _openPlannedExpenseDialog,
              onDeletePlannedExpense: (item) =>
                  _plannedExpenseRepository.delete(item.id),
              onAddDebt: _openDebtDialog,
              onPayDebt: _openDebtPaymentDialog,
              onDeleteDebt: (item) => _debtRepository.delete(item.id),
              onAllocateToDebt: _openDebtAllocationDialog,
              onAllocateToPlannedExpense: _openPlannedExpenseAllocationDialog,
              onSetCategoryBudget: _openCategoryBudgetDialog,
              onDelete: (transaction) =>
                  _financeRepository.delete(transaction.id),
            ),
            SettingsTab(
              onSetPin: _openSetPinDialog,
              onDisablePin: _disablePin,
              onLockNow: () => _securityService.lock(),
              onCreateBackup: _createEncryptedBackup,
              onShareBackupFile: _shareEncryptedBackupFile,
              onRestoreBackup: _restoreEncryptedBackup,
              onExportTasksCsv: _exportTasksCsv,
              onExportFinanceCsv: _exportFinanceCsv,
              onMonthlyReport: _showMonthlyReport,
              onConfigureAvailability: _openAvailabilityDialog,
              onSmartAlertsPreview: _showSmartAlertsPreview,
              onScheduleSmartAlerts: _scheduleSmartAlerts,
              onCalendarPreview: _showCalendarPreview,
              onShareRealPdfReport: _shareRealPdfReport,
              onPrintablePdfReport: _showPrintablePdfReport,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTaskForm([Task? task]) async {
    final result = await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: TaskFormSheet(initialTask: task),
      ),
    );

    if (result == null) return;
    await _homeCoordinator.saveTask(result, isNew: task == null);
  }

  Future<void> _completeTask(Task task) async {
    final actual = await _askActualMinutes(task.estimatedMinutes);
    if (actual == null) return;
    await _homeCoordinator.completeTask(task, actual);

    // حسابدار هوشمند: اگر کار مربوط به کار/درآمد بود، همان لحظه درآمد را می‌پرسد.
    if (_homeCoordinator.shouldAskIncomeForTask(task)) {
      await _askIncomeForCompletedWork(task, actual);
    }
  }

  Future<int?> _askActualMinutes(int initialMinutes) {
    return TaskDialogs.askActualMinutes(context, initialMinutes);
  }

  Future<void> _askIncomeForCompletedWork(Task task, int actualMinutes) async {
    final transaction = await FinanceDialogs.askIncomeForCompletedWork(
      context: context,
      task: task,
      actualMinutes: actualMinutes,
      parseMoney: _parseMoney,
    );

    if (transaction != null) {
      await _homeCoordinator.addTransaction(transaction);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'درآمد ${PersianFormat.money(transaction.amount)} ثبت شد.')),
      );
    }
  }

  Future<void> _openTransactionDialog(FinanceTransactionType type) async {
    final transaction = await FinanceDialogs.openTransactionDialog(
      context: context,
      type: type,
      parseMoney: _parseMoney,
    );

    if (transaction != null) {
      await _homeCoordinator.addTransaction(transaction);
    }
  }

  int _parseMoney(String value) {
    final normalized = PersianFormat.englishDigits(value)
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .trim();
    return int.tryParse(normalized) ?? 0;
  }

  Future<void> _reopenTask(Task task) async {
    await _homeCoordinator.reopenTask(task);
  }

  Future<void> _openGoalsDialog() async {
    final input = await GoalDialogs.goals(
      context: context,
      repository: _goalRepository,
      parseMoney: _parseMoney,
    );
    if (input == null) return;
    await _homeCoordinator.saveGoals(input);
  }

  Future<void> _openSetPinDialog() async {
    final pin = await SecurityDialogs.setPin(context);
    if (pin == null) return;
    await _homeCoordinator.setPin(pin);
  }

  Future<void> _disablePin() async {
    final pin = await CommonDialogs.askSecretText(
      context: context,
      title: 'حذف رمز',
      label: 'رمز فعلی',
    );
    if (pin == null) return;
    final ok = await _homeCoordinator.disablePin(pin);
    _showSnack(ok ? 'قفل برنامه غیرفعال شد.' : 'رمز درست نیست.');
  }

  String _buildEncryptedBackup(String pass) {
    return _homeCoordinator.createEncryptedBackup(pass);
  }

  Future<void> _createEncryptedBackup() async {
    if (!_isFeatureEnabled(
        FeatureFlags.enableEncryptedBackup, 'بکاپ رمزنگاری‌شده')) {
      return;
    }
    final pass = await BackupDialogs.askBackupPassphrase(context,
        title: 'ساخت بکاپ رمزنگاری‌شده');
    if (pass == null) return;
    try {
      final backup = _buildEncryptedBackup(pass);
      await _showLargeText(
          title: 'بکاپ رمزنگاری‌شده', text: backup, copyLabel: 'کپی بکاپ');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _shareEncryptedBackupFile() async {
    if (!_isFeatureEnabled(
        FeatureFlags.enableEncryptedBackup && FeatureFlags.enableShareFiles,
        'اشتراک فایل بکاپ')) {
      return;
    }
    final pass = await BackupDialogs.askBackupPassphrase(context,
        title: 'اشتراک‌گذاری فایل بکاپ');
    if (pass == null) return;
    try {
      final backup = _buildEncryptedBackup(pass);
      final file = await _shareFileService.saveText(
        fileName: 'smart-day-planner-encrypted.backup',
        text: backup,
      );
      await _shareFileService.shareFile(file,
          text: 'بکاپ رمزنگاری‌شده دستیار روزانه ایرانی');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _restoreEncryptedBackup() async {
    if (!_isFeatureEnabled(FeatureFlags.enableEncryptedBackup, 'بازیابی بکاپ')) {
      return;
    }
    final input = await BackupDialogs.restore(context);
    if (input == null) return;
    try {
      await _homeCoordinator.restoreEncryptedBackup(
        encryptedBackup: input.encryptedBackup,
        passphrase: input.passphrase,
      );
      _showSnack('بکاپ با موفقیت بازیابی شد.');
    } catch (e) {
      _showSnack('بازیابی ناموفق بود؛ رمز یا متن بکاپ را بررسی کن.');
    }
  }

  Future<void> _exportTasksCsv() async {
    await _showLargeText(
        title: 'خروجی CSV کارها',
        text: _reportActions.tasksCsv(_repository),
        copyLabel: 'کپی CSV');
  }

  Future<void> _exportFinanceCsv() async {
    await _showLargeText(
        title: 'خروجی CSV مالی',
        text: _reportActions.financeCsv(_financeRepository),
        copyLabel: 'کپی CSV');
  }

  Future<void> _showMonthlyReport() async {
    await _showLargeText(
      title: 'گزارش ماه شمسی',
      text: _reportActions.monthlyTextReport(
        taskRepository: _repository,
        financeRepository: _financeRepository,
        goalRepository: _goalRepository,
      ),
      copyLabel: 'کپی گزارش',
    );
  }

  Future<void> _showLargeText(
      {required String title,
      required String text,
      required String copyLabel}) {
    return CommonDialogs.showLargeText(
      context: context,
      title: title,
      text: text,
      copyLabel: copyLabel,
      onCopied: () => _showSnack('کپی شد.'),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// وقتی یک قابلیت پلتفرمی با feature flag (dart-define) خاموش شده باشد،
  /// عملیات مربوطه اجرا نمی‌شود و پیام مناسب به کاربر نشان داده می‌شود.
  bool _isFeatureEnabled(bool enabled, String featureName) {
    if (enabled) return true;
    _showSnack('قابلیت «$featureName» در این نسخه غیرفعال است.');
    return false;
  }

  Future<void> _openPlannedExpenseDialog() async {
    final input = await PlanningDialogs.plannedExpense(
        context: context, parseMoney: _parseMoney);
    if (input == null || input.amount <= 0) return;
    await _homeCoordinator.addPlannedExpense(input);
  }

  Future<void> _openDebtDialog() async {
    final input =
        await PlanningDialogs.debt(context: context, parseMoney: _parseMoney);
    if (input == null || input.amount <= 0) return;
    await _homeCoordinator.addDebt(input);
  }

  Future<void> _openDebtPaymentDialog(DebtItem item) async {
    final amount = await PlanningDialogs.amount(
      context: context,
      title: item.type == DebtType.debt ? 'ثبت پرداخت بدهی' : 'ثبت دریافت طلب',
      parseMoney: _parseMoney,
      initial: PersianFormat.digits(item.remainingAmount),
    );
    if (amount != null && amount > 0) {
      await _homeCoordinator.settleDebt(item, amount);
    }
  }

  Future<void> _openDebtAllocationDialog(DebtItem item) async {
    await _openAllocationDialog(
      title: 'کنار گذاشتن پول برای بدهی ${item.personName}',
      targetType: AllocationTargetType.debt,
      targetId: item.id,
      note: 'پاکت بدهی ${item.personName}',
    );
  }

  Future<void> _openPlannedExpenseAllocationDialog(
      PlannedExpenseGoal item) async {
    await _openAllocationDialog(
      title: 'کنار گذاشتن پول برای «${item.title}»',
      targetType: AllocationTargetType.plannedExpense,
      targetId: item.id,
      note: 'پاکت ${item.title}',
    );
  }

  Future<void> _openAllocationDialog({
    required String title,
    required AllocationTargetType targetType,
    required String targetId,
    required String note,
  }) async {
    final amount = await PlanningDialogs.amount(
        context: context, title: title, parseMoney: _parseMoney);
    if (amount != null && amount > 0) {
      await _homeCoordinator.allocate(
        targetType: targetType,
        targetId: targetId,
        amount: amount,
        note: note,
      );
    }
  }

  Future<void> _openCategoryBudgetDialog() async {
    final input = await PlanningDialogs.categoryBudget(
        context: context, parseMoney: _parseMoney);
    if (input == null) return;
    await _homeCoordinator.saveCategoryBudget(input);
  }

  Future<void> _openAvailabilityDialog() async {
    final current = _availabilityRepository.settings;
    final input = await PlanningDialogs.availability(
      context: context,
      startHour: current.startHour,
      endHour: current.endHour,
      breakMinutesPerHour: current.breakMinutesPerHour,
      fridayOff: current.offWeekdays.contains(DateTime.friday),
    );
    if (input == null) return;
    await _homeCoordinator.saveAvailability(input);
  }

  Future<void> _showSmartAlertsPreview() async {
    if (!_isFeatureEnabled(
        FeatureFlags.enableSmartNotifications, 'هشدارهای هوشمند')) {
      return;
    }
    final alerts = _notificationAdvisor.buildAlerts(
      debts: _debtRepository,
      plannedExpenses: _plannedExpenseRepository,
      allocations: _allocationRepository,
      budgets: _categoryBudgetRepository,
      finance: _financeRepository,
    );
    await _showLargeText(
        title: 'پیش‌نمایش هشدارهای هوشمند',
        text: alerts.map((e) => '• $e').join('\n'),
        copyLabel: 'کپی هشدارها');
  }

  Future<void> _showPrintablePdfReport() async {
    if (!_isFeatureEnabled(FeatureFlags.enablePdfExport, 'خروجی PDF')) return;
    final html = _reportActions.printableHtmlReport(
      taskRepository: _repository,
      financeRepository: _financeRepository,
      goalRepository: _goalRepository,
    );
    await _showLargeText(
        title: 'گزارش HTML آماده PDF', text: html, copyLabel: 'کپی HTML');
  }

  Future<void> _shareRealPdfReport() async {
    if (!_isFeatureEnabled(
        FeatureFlags.enablePdfExport && FeatureFlags.enableShareFiles,
        'PDF و اشتراک‌گذاری')) {
      return;
    }
    try {
      await _reportActions.shareRealPdfReport(
        taskRepository: _repository,
        financeRepository: _financeRepository,
        goalRepository: _goalRepository,
      );
    } catch (e) {
      _showSnack('ساخت یا اشتراک‌گذاری PDF ناموفق بود.');
    }
  }

  Future<void> _showCalendarPreview() async {
    if (!_isFeatureEnabled(FeatureFlags.enableCalendar, 'تقویم گوشی')) return;
    final text = await _reportActions.calendarPreviewText(_calendarService);
    await _showLargeText(
        title: 'رویدادهای تقویم ۷ روز آینده', text: text, copyLabel: 'کپی');
  }

  Future<void> _scheduleSmartAlerts() async {
    if (!_isFeatureEnabled(
        FeatureFlags.enableSmartNotifications, 'زمان‌بندی هشدار')) {
      return;
    }
    final count = await _reportActions.scheduleSmartAlerts(
      scheduler: _smartNotificationScheduler,
      debtRepository: _debtRepository,
      plannedExpenseRepository: _plannedExpenseRepository,
      allocationRepository: _allocationRepository,
      categoryBudgetRepository: _categoryBudgetRepository,
      financeRepository: _financeRepository,
    );
    _showSnack(count == 0
        ? 'هشدار فوری برای زمان‌بندی پیدا نشد.'
        : '${PersianFormat.digits(count)} هشدار برای فردا زمان‌بندی شد.');
  }

  Future<void> _deleteTask(Task task) async {
    final ok = await TaskDialogs.confirmDelete(context, task);
    if (ok) {
      await _homeCoordinator.deleteTask(task);
    }
  }

  String _buildAssistantStatusLabel(LocalLlmAdapter assistant) {
    if (FeatureFlags.enableOnlineAi && OnlineAiConfig.instance.hasKey) {
      return 'هوش مصنوعی آنلاین فعال ✨';
    }
    if (FeatureFlags.enableLocalLlm) {
      return assistant is HybridLocalAssistant
          ? assistant.statusLabel
          : 'هوش قانونی (بدون LLM)';
    }
    return 'هوش قانونی (بدون LLM)';
  }

  Future<void> _askAssistant() async {
    final prompt = _assistantController.text.trim();
    if (prompt.isEmpty) return;
    _assistantController.clear();
    await _processUserRequest(prompt);
  }

  /// پردازش یک درخواست (متن یا صدا) و ساخت پاسخ چت.
  Future<void> _processUserRequest(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (mounted) {
      setState(() {
        _chatMessages.add(ChatMessage(text: t, isUser: true));
        _isTyping = true;
      });
    }

    String answer;
    final trace = TraceStore.instance.start(t);

    // ۱) مسیریابی هوشمند: اول سناریوی برنامه‌ریزی هوشمند را امتحان کن.
    final planner = ref.read(smartPlannerAgentProvider);
    final workProfile = ref
        .read(workLearningServiceProvider)
        .profile(tasks: _repository.tasks, transactions: _financeRepository.transactions);
    trace.step('بررسی سناریوی هوشمند');
    final scenario = await planner.handle(
      rawText: t,
      taskRepository: _repository,
      financeRepository: _financeRepository,
      workProfile: workProfile,
    );
    if (scenario.message.isNotEmpty) {
      answer = scenario.message;
      trace.step('پاسخ از سناریوی هوشمند',
          detail: 'پاسخ (${answer.length} کاراکتر)');
    } else if (FeatureFlags.enableAutonomousAgent && _isAutonomousCommand(t)) {
      trace.step('شناسایی فرمان اجرایی', detail: 'به عامل خودکار ارجاع شد');
      final agent = ref.read(autonomousAgentServiceProvider);
      final result = await agent.handleAutonomously(
        rawText: t,
        taskRepository: _repository,
        financeRepository: _financeRepository,
        goalRepository: _goalRepository,
        debtRepository: _debtRepository,
        plannedExpenseRepository: _plannedExpenseRepository,
        allocationRepository: _allocationRepository,
        conversationMemory: _conversationMemoryService,
      );
      answer = result.message;
      trace.step('فرمان اجرایی انجام شد',
          detail: 'پاسخ (${answer.length} کاراکتر)');
    } else {
      trace.step('ارجاع به دستیار گفتگو');
      final assistant = ref.read(intelligentAssistantProvider);
      answer = await assistant.ask(
        userText: t,
        tasks: _repository.tasks,
      );
    }
    trace.step('پایان پردازش', detail: 'پاسخ نهایی (${answer.length} کاراکتر)');

    if (mounted) {
      setState(() {
        _isTyping = false;
        _chatMessages.add(ChatMessage(text: answer, isUser: false));
      });
    }
    if (FeatureFlags.enableVoiceResponse) {
      await _voiceResponseService.speak(answer);
    }
  }

  bool _isAutonomousCommand(String text) {
    final lower = VoiceNlu.normalize(text).toLowerCase();
    const keywords = [
      'بدهکار',
      'بدهی',
      'کنار بذار',
      'کنار بگذار',
      'پرداخت',
      'هزینه',
      'کار جدید',
      'کار دارم',
      'قرار دارم',
      'جلسه دارم',
      'کلاس دارم',
      'شیفت دارم',
      'جلسه کاری',
      'قرار کاری',
      'قرض',
      'وام',
      'وظیفه',
      'خرج',
      'تومان',
      'هزار',
      'میلیون',
      'میل',
      'میلیارد',
      'حساب',
      'مانده',
      'پرونده',
      'خورد خورد',
      'قسط',
      'تایید',
      'لغو'
    ];
    if (keywords.any(lower.contains)) return true;
    // اسم تنها مثل «فرهاد» یا پرسش پرونده «بدهی فرهاد»
    if (VoiceNlu.isSinglePersianName(lower.trim())) return true;
    if (VoiceNlu.extractPersonNameForQuery(lower).isNotEmpty) {
      if (lower.contains('بدهی') || lower.contains('قرض') || lower.contains('وام') || lower.contains('حساب') || lower.contains('مانده') || lower.contains('پرونده') || lower.contains('چقدر')) {
        return true;
      }
    }
    // جمله‌های طبیعی مثل «فردا ساعت ۲ کار دارم» بدون کلمهٔ «کار جدید»
    // و همچنین «فردا ساعت ۱۴ جلسه کاری دارم»
    final hasDateOrTime = lower.contains('فردا') ||
        lower.contains('امروز') ||
        lower.contains('پس فردا') ||
        lower.contains('این هفته') ||
        lower.contains('هفته دیگه') ||
        lower.contains('ساعت');
    final hasTaskPhrase = lower.contains('کار دارم') ||
        lower.contains('قرار دارم') ||
        lower.contains('جلسه دارم') ||
        lower.contains('کلاس دارم') ||
        lower.contains('شیفت دارم');
    if (hasDateOrTime && hasTaskPhrase) return true;
    // حالت کوتاه: «ساعت ۳ جلسه» + تاریخ
    if (hasDateOrTime &&
        (lower.contains('قرار') ||
            lower.contains('جلسه') ||
            lower.contains('کلاس') ||
            lower.contains('شیفت')) &&
        lower.contains('ساعت')) {
      return true;
    }
    return false;
  }
}
