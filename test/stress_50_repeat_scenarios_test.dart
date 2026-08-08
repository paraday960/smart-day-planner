import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/database_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/smart_planner_agent.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_command_processor.dart';
import 'package:smart_day_planner/services/work_learning_service.dart';

/// پاک‌کردن کامل دیتابیس — تا هر تست از حالت «صفر» شروع شود (در غیر این
/// صورت فایل db بین اجراهای پشت‌سرهم باقی می‌ماند و شمارش‌ها تجمعی می‌شود).
Future<void> _wipeDatabase() async {
  try {
    await DatabaseService.instance.close();
  } catch (_) {}
  final path = p.join(await getDatabasesPath(), 'smart_day_planner.db');
  await databaseFactory.deleteDatabase(path);
}

/// ─────────────────────────────────────────────────────────────────────────
/// تست استرس: ۵۰ اجرای تکراری
///   • ۱۰ سناریوی پایه × ۵ بار تکرار = ۵۰ اجرا
///     - فرمان‌های فقط‌خواندنی باید در هر ۵ تکرار پاسخ یکسان بدهند
///       (موتور قانون‌محور قطعی است).
///     - هیچ اجرایی نباید خطا/پیام فنی تولید کند.
///   • تکرار یک فرمان stateful (افزودن کار ×۵) — رفتار انباشتی درست.
///   • آزمون یادگیری SmartPlannerAgent: سناریوی یکسان ×۵ — اجرای اول
///     محاسبه می‌شود و اجراهای بعدی از حافظهٔ یادگیری (reused) می‌آیند.
/// ─────────────────────────────────────────────────────────────────────────

const _technicalMarkers = [
  'Exception',
  'TypeError',
  'RangeError',
  'Unhandled',
  'هنوز به فرمان صوتی وصل نشده',
];

void _expectNoTechnicalErrors(String response, String step) {
  for (final marker in _technicalMarkers) {
    expect(response.contains(marker), isFalse,
        reason: 'پاسخ «$step» حاوی «$marker» است: $response');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('سناریوهای تکراری', () {
    test('۵۰ اجرای تکراری (۱۰ سناریو × ۵ بار): بدون خطا و با پاسخ یکسان',
        () async {
      await _wipeDatabase();
      const baseScenarios = [
        'سلام',
        'برنامه امروزمو بچین',
        'الان چیکار کنم',
        'وضع مالی من چطوره',
        'راهنما',
        'چی عقب مونده',
        'درآمد امروز چقدره',
        'ریسک مالی دارم؟',
        'کار بعدی چیه',
        'بهترین کار بعدی',
      ];
      expect(baseScenarios, hasLength(10));

      final memory = ConversationMemoryService();
      await memory.load();
      final processor = VoiceCommandProcessor(
        taskRepository: TaskRepository(),
        financeRepository: FinanceRepository(),
        goalRepository: GoalRepository(),
        debtRepository: DebtRepository(),
        plannedExpenseRepository: PlannedExpenseRepository(),
        allocationRepository: AllocationRepository(),
        conversationMemory: memory,
      );

      var totalRuns = 0;
      for (final step in baseScenarios) {
        String? firstResponse;
        for (var i = 0; i < 5; i++) {
          final response = await processor.handle(step);
          expect(response, isNotEmpty, reason: 'تکرار $i: پاسخ خالی برای «$step»');
          _expectNoTechnicalErrors(response, step);
          if (i == 0) {
            firstResponse = response;
          } else {
            expect(response, firstResponse,
                reason: 'تکرار $i از «$step» با تکرار اول فرق دارد — '
                    'موتور قانون‌محور باید قطعی باشد.');
          }
          totalRuns++;
        }
      }
      expect(totalRuns, 50, reason: 'باید دقیقاً ۵۰ اجرای تکراری انجام شود.');
    });

    test('تکرار ۵ بار یک فرمان stateful (افزودن کار): بدون خطا و انباشت درست',
        () async {
      await _wipeDatabase();
      final taskRepo = TaskRepository();
      final memory = ConversationMemoryService();
      await memory.load();
      final processor = VoiceCommandProcessor(
        taskRepository: taskRepo,
        financeRepository: FinanceRepository(),
        goalRepository: GoalRepository(),
        debtRepository: DebtRepository(),
        plannedExpenseRepository: PlannedExpenseRepository(),
        allocationRepository: AllocationRepository(),
        conversationMemory: memory,
      );

      const command = 'کار جدید اضافه کن تست تکراری';
      for (var i = 1; i <= 5; i++) {
        final response = await processor.handle(command);
        expect(response, contains('اضافه شد'),
            reason: 'تکرار $i: «$command» باید کار را اضافه کند.');
        _expectNoTechnicalErrors(response, command);
        expect(taskRepo.tasks.length, i,
            reason: 'بعد از تکرار $i باید دقیقاً $i کار اضافه شده باشد.');
      }
    });

    test('یادگیری agent: سناریوی یکسان ×۵ — اجرای اول محاسبه، بقیه از حافظه',
        () async {
      await _wipeDatabase();
      SmartScenarioMemory.instance.reset();
      await SmartScenarioMemory.instance.load();

      final taskRepo = TaskRepository();
      final agent = SmartPlannerAgent(onlineBackend: null);

      const scenario = 'من یک میلیون پول دارم و هفته دیگه باید با دوستم برم بیرون';
      final reuses = <bool>[];
      for (var i = 0; i < 5; i++) {
        final result = await agent.handle(
          rawText: scenario,
          taskRepository: taskRepo,
          financeRepository: FinanceRepository(),
          workProfile: WorkProfile.empty,
        );
        expect(result.message, isNotEmpty,
            reason: 'تکرار $i: پیام سناریو نباید خالی باشد.');
        _expectNoTechnicalErrors(result.message, 'agent:$scenario');
        reuses.add(result.reused);
      }

      // اجرای اول: محاسبه شد (reused=false)؛ چهار اجرای بعدی: از حافظه.
      expect(reuses.first, isFalse);
      expect(reuses.sublist(1).every((r) => r), isTrue,
          reason: 'چهار تکرار بعدی باید از حافظهٔ یادگیری اجرا شوند: $reuses');

      // هر اجرا یک «قرار» با دوست ساخته است.
      final eventTasks =
          taskRepo.tasks.where((t) => t.title.contains('دوست')).toList();
      expect(eventTasks, hasLength(5),
          reason: '۵ تکرار باید ۵ قرار بسازد (هر بار از حافظه اجرا شود).');
    });
  });
}
