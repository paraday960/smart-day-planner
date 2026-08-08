import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_day_planner/models/money_allocation.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/database_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/feedback_learning_service.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/llama_backend.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/smart_planner_agent.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_command_processor.dart';
import 'package:smart_day_planner/services/work_learning_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// تست «یادگیری» برنامه — عمق یادگیری، نه فقط پردازش:
///
/// ۱. کارایی یادگیری agent: بعد از اجرای اولِ یک سناریو، هوش آنلاین دیگر
///    صدا زده نمی‌شود و اقدامات اجراهای بعدی دقیقاً همان اقدامات یادگرفته‌شده
///    است (یکسان‌سازی عمیق) + ماندگاری حافظه روی دیسک.
/// ۲. یادگیری گفتگو: موجودیت «بدهی» به‌خاطر سپرده می‌شود و فرمان «براش»
///    دقیقاً همان موجودیت را هدف می‌گیرد.
/// ۳. یادگیری کاری: تکمیل کار با زمان واقعی، پروفایل کاری را به‌روز می‌کند.
/// ۴. یادگیری بازخورد: بازخورد مثبت/منفی، وزن پیشنهاد را تغییر می‌دهد.
/// ─────────────────────────────────────────────────────────────────────────

Future<void> _wipeDatabase() async {
  try {
    await DatabaseService.instance.close();
  } catch (_) {}
  final path = p.join(await getDatabasesPath(), 'smart_day_planner.db');
  await databaseFactory.deleteDatabase(path);
}

/// بک‌اند جعلی با شمارنده — برای سنجش «چند بار هوش آنلاین صدا زده شد».
class _CountingBackend implements LlmBackend {
  int calls = 0;

  @override
  Future<bool> get available async => true;

  @override
  Future<String> generate(String prompt) async {
    calls++;
    return 'برنامه: یک قرار اضافه کن';
  }
}

VoiceCommandProcessor _buildProcessor({
  required TaskRepository task,
  required FinanceRepository finance,
  required GoalRepository goal,
  required DebtRepository debt,
  required PlannedExpenseRepository planned,
  required AllocationRepository allocation,
  required ConversationMemoryService memory,
}) {
  return VoiceCommandProcessor(
    taskRepository: task,
    financeRepository: finance,
    goalRepository: goal,
    debtRepository: debt,
    plannedExpenseRepository: planned,
    allocationRepository: allocation,
    conversationMemory: memory,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('سنجش یادگیری برنامه', () {
    test(
        '۱) یادگیری agent: اجرای اول از هوش آنلاین می‌پرسد، ۴ اجرای بعدی '
        'بدون هوش آنلاین و با اقدامات یکسان اجرا می‌شوند', () async {
      await _wipeDatabase();
      SmartScenarioMemory.instance.reset();
      await SmartScenarioMemory.instance.load();

      final backend = _CountingBackend();
      final taskRepo = TaskRepository();
      final agent = SmartPlannerAgent(onlineBackend: backend);

      const scenario =
          'من دو میلیون پول دارم و هفته دیگه باید با دوستم برم بیرون';
      final results = <SmartPlanResult>[];
      for (var i = 0; i < 5; i++) {
        results.add(await agent.handle(
          rawText: scenario,
          taskRepository: taskRepo,
          financeRepository: FinanceRepository(),
          workProfile: WorkProfile.empty,
        ));
      }

      // ── کارایی یادگیری: هوش آنلاین فقط برای اجرای اول صدا زده شد ──
      expect(backend.calls, 1,
          reason: 'بعد از یادگیری، ۴ تکرار نباید دوباره به هوش آنلاین بروند.');

      // ── یکپارچگی حافظه: اقدامات اجراهای بعدی == اقدامات اجرای اول ──
      final firstActions =
          results.first.actions.map((a) => a.toJson()).toList();
      expect(firstActions, isNotEmpty);
      for (final r in results.skip(1)) {
        expect(r.reused, isTrue,
            reason: 'اجرای ${results.indexOf(r)} باید از حافظه بازاستفاده کند.');
        expect(
          r.actions.map((a) => a.toJson()).toList(),
          firstActions,
          reason: 'اقدامات یادگرفته‌شده باید با اجرای اول یکسان باشد.',
        );
      }

      // ── ماندگاری: agent تازه (با بک‌اند تازه) هم از حافظهٔ روی دیسک استفاده می‌کند ──
      final freshBackend = _CountingBackend();
      final freshAgent = SmartPlannerAgent(onlineBackend: freshBackend);
      final reloaded = await freshAgent.handle(
        rawText: scenario,
        taskRepository: TaskRepository(),
        financeRepository: FinanceRepository(),
        workProfile: WorkProfile.empty,
      );
      expect(reloaded.reused, isTrue,
          reason: 'حافظه باید بعد از بارگذاری مجدد هم در دسترس باشد.');
      expect(freshBackend.calls, 0,
          reason: 'agent تازه هم نباید هوش آنلاین را صدا بزند.');
    });

    test('۲) یادگیری گفتگو: موجودیت بدهی به‌خاطر سپرده می‌شود و «براش» همان را هدف می‌گیرد',
        () async {
      await _wipeDatabase();
      final memory = ConversationMemoryService();
      await memory.load();
      final debtRepo = DebtRepository();
      final allocRepo = AllocationRepository();
      final processor = _buildProcessor(
        task: TaskRepository(),
        finance: FinanceRepository(),
        goal: GoalRepository(),
        debt: debtRepo,
        planned: PlannedExpenseRepository(),
        allocation: allocRepo,
        memory: memory,
      );

      await processor.handle('به ممد بدهکارم');
      await processor.handle('یک میلیون تومان');
      await processor.handle('تا دو روز دیگه');

      final debt = debtRepo.items.single;
      // ── حافظه یاد گرفته چه کسی آخرین موجودیت بوده ──
      expect(memory.lastEntity['type'], 'debt');
      expect(memory.lastEntity['id'], debt.id);

      // فرمان «براش» باید به همان موجودیتِ یادگرفته‌شده اشاره کند
      final ask = await processor.handle('پونصد براش کنار بذار');
      expect(ask, contains('تأیید'));
      await processor.handle('تأیید');

      expect(allocRepo.items.single.targetType, AllocationTargetType.debt);
      expect(allocRepo.items.single.targetId, debt.id,
          reason: 'کنارگذاری باید دقیقاً همان بدهیِ به‌خاطر سپرده‌شده را هدف بگیرد.');
    });

    test('۳) یادگیری کاری: تکمیل کار با زمان واقعی، پروفایل کاری را به‌روز می‌کند',
        () async {
      await _wipeDatabase();
      final taskRepo = TaskRepository();
      final finRepo = FinanceRepository();
      final processor = _buildProcessor(
        task: taskRepo,
        finance: finRepo,
        goal: GoalRepository(),
        debt: DebtRepository(),
        planned: PlannedExpenseRepository(),
        allocation: AllocationRepository(),
        memory: ConversationMemoryService(),
      );

      await processor.handle('کار جدید اضافه کن یادگیری کاری');
      final done = await processor.handle('کار یادگیری کاری کامل شد در ۱۲۰ دقیقه');
      expect(done, contains('کامل شد'));

      final task = taskRepo.tasks.single;
      expect(task.isDone, isTrue);
      expect(task.actualMinutes, 120);

      // ── پروفایل کاری باید از همین یک نمونه یاد گرفته باشد ──
      final profile = const WorkLearningService().profile(
        tasks: taskRepo.tasks,
        transactions: finRepo.transactions,
      );
      expect(profile.sampleCount, greaterThanOrEqualTo(1));
      expect(profile.avgDailyWorkMinutes, closeTo(120, 1),
          reason: 'میانگین کار روزانه باید از زمان واقعی تکمیل یاد گرفته شود.');
      expect(profile.historyDays, greaterThanOrEqualTo(1));
    });

    test('۴) یادگیری بازخورد: «عالی بود» وزن را زیاد و «بد بود» وزن را کم می‌کند',
        () async {
      await _wipeDatabase();
      final processor = _buildProcessor(
        task: TaskRepository(),
        finance: FinanceRepository(),
        goal: GoalRepository(),
        debt: DebtRepository(),
        planned: PlannedExpenseRepository(),
        allocation: AllocationRepository(),
        memory: ConversationMemoryService(),
      );
      final feedback = FeedbackLearningService();

      // پیش از بازخورد: وزنی ثبت نشده است
      final before = await feedback.getWeights();
      expect(before['general'], isNull);

      // ── بازخورد مثبت: وزن بالاتر از ۱ ──
      final posResponse = await processor.handle('عالی بود');
      expect(posResponse, contains('یاد گرفتم'));
      final afterPositive = (await feedback.getWeights())['general'];
      expect(afterPositive, isNotNull);
      expect(afterPositive!, greaterThan(1.0),
          reason: 'بازخورد مثبت باید وزن پیشنهاد را افزایش دهد.');

      // ── بازخورد منفی: وزن کمتر از ۱ (1.1 × 0.85 = 0.935) ──
      final negResponse = await processor.handle('بد بود');
      expect(negResponse, contains('یاد گرفتم'));
      final afterNegative = (await feedback.getWeights())['general'];
      expect(afterNegative, isNotNull);
      expect(afterNegative!, lessThan(1.0),
          reason: 'بازخورد منفی باید وزن پیشنهاد را کاهش دهد.');
    });
  });
}
