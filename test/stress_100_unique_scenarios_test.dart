import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/money_allocation.dart';
import 'package:smart_day_planner/services/allocation_repository.dart';
import 'package:smart_day_planner/services/conversation_memory_service.dart';
import 'package:smart_day_planner/services/database_service.dart';
import 'package:smart_day_planner/services/debt_repository.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/goal_repository.dart';
import 'package:smart_day_planner/services/planned_expense_repository.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/voice_command_processor.dart';

/// پاک‌کردن کامل دیتابیس — تا اجرای هر تست از حالت «صفر» شروع شود.
/// (در غیر این صورت فایل db بین اجراهای پشت‌سرهم در محیط محلی باقی می‌ماند
/// و شمارش کارها/تراکنش‌ها تجمعی می‌شود.)
Future<void> _wipeDatabase() async {
  try {
    await DatabaseService.instance.close();
  } catch (_) {}
  final path = p.join(await getDatabasesPath(), 'smart_day_planner.db');
  await databaseFactory.deleteDatabase(path);
}

/// ─────────────────────────────────────────────────────────────────────────
/// تست استرس: ۱۰۰ سناریوی غیرتکراری از کل لولهٔ پردازش فرمان صوتی
/// (نرمال‌سازی → NLU → دستیار قانون‌محور → مخازن واقعی sqflite).
///
/// برای هر سناریو یک حافظهٔ گفتگو (ConversationMemory) تازه ساخته می‌شود تا
/// وضعیت «مکالمهٔ نیمه‌کاره» از سناریویی به سناریوی دیگر نشت نکند؛ مخازن
/// واقعی مشترک‌اند تا رفتار انباشتی برنامه هم سنجیده شود.
/// ─────────────────────────────────────────────────────────────────────────

class Scenario {
  Scenario(this.name, this.steps, {this.verify});
  final String name;

  /// یک یا چند جمله (سناریوهای چندمرحله‌ای مثل ثبت بدهی).
  final List<String> steps;

  /// بررسی اثر روی مخازن (اختیاری — فقط برای سناریوهای stateful).
  final void Function(ScenarioEnv env)? verify;
}

class ScenarioEnv {
  ScenarioEnv({
    required this.task,
    required this.finance,
    required this.goal,
    required this.debt,
    required this.planned,
    required this.allocation,
  });
  final TaskRepository task;
  final FinanceRepository finance;
  final GoalRepository goal;
  final DebtRepository debt;
  final PlannedExpenseRepository planned;
  final AllocationRepository allocation;
}

/// پیام‌های فنی که نباید هرگز به کاربر برسند.
const _technicalMarkers = [
  'Exception',
  'TypeError',
  'RangeError',
  'Unhandled',
  'هنوز به فرمان صوتی وصل نشده',
];

void _expectNoTechnicalErrors(String response, String scenario, String step) {
  for (final marker in _technicalMarkers) {
    expect(
      response.contains(marker),
      isFalse,
      reason: '[$scenario] پاسخ «$step» حاوی نشانهٔ فنی «$marker» است: $response',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('سناریوهای غیرتکراری', () {
    test('فهرست ۱۰۰ سناریو دقیقاً ۱۰۰ مورد است و جمله‌های اول یکتا هستند', () {
      expect(scenarios, hasLength(100));
      final firstSteps = scenarios.map((s) => s.steps.first).toList();
      expect(firstSteps.toSet(), hasLength(100),
          reason: 'جمله‌های اول سناریوها باید همگی یکتا باشند (غیرتکراری).');
      for (final s in scenarios) {
        expect(s.steps, isNotEmpty, reason: '${s.name}: بدون جمله');
        for (final step in s.steps) {
          expect(step.trim(), isNotEmpty, reason: '${s.name}: جملهٔ خالی');
        }
      }
    });

    test('اجرای ۱۰۰ سناریوی غیرتکراری روی کل لولهٔ پردازش', () async {
      await _wipeDatabase();
      final env = ScenarioEnv(
        task: TaskRepository(),
        finance: FinanceRepository(),
        goal: GoalRepository(),
        debt: DebtRepository(),
        planned: PlannedExpenseRepository(),
        allocation: AllocationRepository(),
      );

      for (final scenario in scenarios) {
        // حافظهٔ گفتگوی تازه برای هر سناریو → عدم نشت مکالمهٔ نیمه‌کاره
        final memory = ConversationMemoryService();
        await memory.load();
        final processor = VoiceCommandProcessor(
          taskRepository: env.task,
          financeRepository: env.finance,
          goalRepository: env.goal,
          debtRepository: env.debt,
          plannedExpenseRepository: env.planned,
          allocationRepository: env.allocation,
          conversationMemory: memory,
        );

        String last = '';
        for (final step in scenario.steps) {
          last = await processor.handle(step);
          expect(last, isNotEmpty,
              reason: '[${scenario.name}] پاسخ خالی برای «$step»');
          _expectNoTechnicalErrors(last, scenario.name, step);
        }
        scenario.verify?.call(env);
      }
    });
  });
}

/// ── ۱۰۰ سناریوی غیرتکراری ────────────────────────────────────────────────
final List<Scenario> scenarios = [
  // ── گروه ۱: سلام و گفتگو (۱۰) ────────────────────────────────────────────
  Scenario('سلام ساده', ['سلام']),
  Scenario('درود', ['درود']),
  Scenario('صبح بخیر', ['صبح بخیر']),
  Scenario('ظهر بخیر', ['ظهر بخیر']),
  Scenario('عصر بخیر', ['عصر بخیر']),
  Scenario('شب بخیر', ['شب بخیر']),
  Scenario('سلام علیکم', ['سلام علیکم']),
  Scenario('سلام خوبی', ['سلام خوبی']),
  Scenario('صبحت بخیر', ['صبحت بخیر']),
  Scenario('درود بر شما', ['درود بر شما']),

  // ── گروه ۲: تشکر (۸) ─────────────────────────────────────────────────────
  Scenario('ممنون', ['ممنون']),
  Scenario('مرسی', ['مرسی']),
  Scenario('سپاس', ['سپاس']),
  Scenario('تشکر', ['تشکر']),
  Scenario('دمت گرم', ['دمت گرم']),
  Scenario('دستت درد نکنه', ['دستت درد نکنه']),
  Scenario('عالی بود', ['عالی بود']),
  Scenario('خیلی ممنون ازت', ['خیلی ممنون ازت']),

  // ── گروه ۳: راهنما (۱۰) ──────────────────────────────────────────────────
  Scenario('راهنما', ['راهنما']),
  Scenario('کمک', ['کمک']),
  Scenario('چه کارهایی بلدی', ['چه کارهایی بلدی']),
  Scenario('چه کارهایی میتونی', ['چه کارهایی میتونی']),
  Scenario('چه چیزهایی بلدی', ['چه چیزهایی بلدی']),
  Scenario('چطور استفاده کنم', ['چطور استفاده کنم']),
  Scenario('چطوری استفاده کنم', ['چطوری استفاده کنم']),
  Scenario('کمکم کن', ['کمکم کن']),
  Scenario('چیکار میتونی بکنی', ['چیکار میتونی بکنی']),
  Scenario('چه کارهایی انجام میدی', ['چه کارهایی انجام میدی']),

  // ── گروه ۴: پرس‌وجوی کارها (۱۴) ─────────────────────────────────────────
  Scenario('برنامه امروز', ['برنامه امروز']),
  Scenario('امروز چیکار کنم', ['امروز چیکار کنم']),
  Scenario('برنامه امروزمو بچین', ['برنامه امروزمو بچین']),
  Scenario('زمان بندی امروز', ['زمان بندی امروز']),
  Scenario('برنامه هفته', ['برنامه هفته']),
  Scenario('این هفته چیکار کنم', ['این هفته چیکار کنم']),
  Scenario('فردا چیکار کنم', ['فردا چیکار کنم']),
  Scenario('برنامه فردا', ['برنامه فردا']),
  Scenario('چی عقب مونده', ['چی عقب مونده']),
  Scenario('کارهای عقب افتاده', ['کارهای عقب افتاده']),
  Scenario('چند کار دیر شده', ['چند کار دیر شده']),
  Scenario('الان چیکار کنم', ['الان چیکار کنم']),
  Scenario('کار بعدی چیه', ['کار بعدی چیه']),
  Scenario('اول کدوم رو انجام بدم', ['اول کدوم رو انجام بدم']),

  // ── گروه ۵: افزودن کار (۱۰) — stateful ──────────────────────────────────
  Scenario('افزودن کار: خرید کتاب', ['کار جدید اضافه کن خرید کتاب'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: ورزش صبحگاهی', ['وظیفه جدید ثبت کن ورزش صبحگاهی'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: تمیزکاری', ['اضافه کن تمیزکاری خونه'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: مطالعه', ['ثبت کن مطالعه برنامه نویسی'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: یادآوری پیام', ['یادم بنداز جواب پیام رضا رو بدم'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار مهم: جلسه مشتری', ['کار جدید خیلی مهم اضافه کن جلسه با مشتری'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار فوری: قبض برق', ['کار جدید فوری ثبت کن پرداخت قبض برق'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: گیتار ساعت ۸ شب', ['اضافه کن تمرین گیتار ساعت ۸ شب'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: خرید برای فردا', ['ثبت کن خرید مواد غذایی برای فردا'],
      verify: (e) => _verifyTasksAdded(e, 1)),
  Scenario('افزودن کار: گزارش هفتگی', ['کار جدید اضافه کن نوشتن گزارش هفتگی'],
      verify: (e) => _verifyTasksAdded(e, 1)),

  // ── گروه ۶: ثبت درآمد (۱۰) — stateful ───────────────────────────────────
  Scenario('درآمد دو میلیون', ['درآمد دو میلیون تومان'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('پول گرفتم پونصد', ['پول گرفتم پونصد هزار تومان'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('دریافتی یک میلیون و دویست', ['دریافتی یک میلیون و دویست هزار تومان'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('واریز پانصد هزار', ['واریز شد پانصد هزار تومان'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('درآمد سیصد هزار ثبت کن', ['درآمد سیصد هزار تومان ثبت کن'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('پول گرفتم دستمزد', ['پول گرفتم سه میلیون دستمزد'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('درآمد از فروش', ['درآمد چهارصد و پنجاه هزار تومان از فروش'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('پول از مشتری', ['پول گرفتم صد و پنجاه هزار از مشتری'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('دریافتی نهصد هزار', ['دریافتی نهصد هزار تومان'],
      verify: (e) => _verifyIncomesAdded(e, 1)),
  Scenario('درآمد از تدریس', ['درآمد هفتصد و پنجاه هزار تومان از تدریس'],
      verify: (e) => _verifyIncomesAdded(e, 1)),

  // ── گروه ۷: ثبت هزینه (۱۰) — stateful (احتمال تأیید) ───────────────────
  Scenario('هزینه خواربار', ['هزینه دویست هزار تومان برای خواربار', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('خرج ناهار', ['خرج ناهار هشتاد هزار تومان', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('پرداخت بنزین', ['پرداخت کردم صد و بیست هزار برای بنزین', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('هزینه پنجاه هزار', ['هزینه پنجاه هزار تومان ثبت کن', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('خرج کتاب', ['خرج خرید کتاب هفتاد هزار تومان', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('هزینه پزشک', ['هزینه سیصد هزار تومان برای پزشک', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('پرداخت کرایه', ['پرداخت کردم نود هزار تومان کرایه', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('خرج کادو تولد', ['خرج کادو تولد دویست و پنجاه هزار', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('هزینه اینترنت', ['هزینه اینترنت صد و ده هزار تومان', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),
  Scenario('پرداخت تاکسی', ['پرداخت کردم چهل هزار تومان برای تاکسی', 'تأیید'],
      verify: (e) => _verifyExpensesAdded(e, 1)),

  // ── گروه ۸: وضعیت مالی و هدف (۸) ────────────────────────────────────────
  Scenario('وضع مالی', ['وضع مالی من چطوره']),
  Scenario('حسابم', ['حسابم چطوره']),
  Scenario('درآمد امروز', ['درآمد امروز چقدره']),
  Scenario('درآمد این ماه', ['درآمد این ماه']),
  Scenario('چقدر مونده', ['چقدر مونده']),
  Scenario('چقدر باید کار کنم', ['چقدر باید کار کنم']),
  Scenario('هدف درآمد روزانه', ['هدف درآمد روزانه یک میلیون تومان'],
      verify: (e) => expect(e.goal.dailyIncomeGoal, 1000000)),
  Scenario('هدف درآمد ماهانه', ['هدف درآمد ماهانه ده میلیون تومان'],
      verify: (e) => expect(e.goal.monthlyIncomeGoal, 10000000)),

  // ── گروه ۹: بدهی (۱۰) — stateful ────────────────────────────────────────
  Scenario('ثبت بدهی ممد', ['به ممد بدهکارم', 'یک میلیون تومان', 'تا دو روز دیگه'],
      verify: (e) => _verifyDebtAdded(e, 'ممد')),
  Scenario('ثبت بدهی علی', ['به علی بدهکارم', 'پونصد هزار تومان', 'تا هفته دیگه'],
      verify: (e) => _verifyDebtAdded(e, 'علی')),
  Scenario('ثبت بدهی رضا', ['به رضا بدهکارم', 'دو میلیون تومان', 'تا یک ماه دیگه'],
      verify: (e) => _verifyDebtAdded(e, 'رضا')),
  Scenario('ثبت بدهی سارا', ['به سارا بدهکارم', 'هشتصد هزار تومان', 'تا سه روز دیگه'],
      verify: (e) => _verifyDebtAdded(e, 'سارا')),
  Scenario('ثبت بدهی حسین', ['به حسین بدهکارم', 'یک میلیون و پونصد هزار', 'تا ده روز دیگه'],
      verify: (e) => _verifyDebtAdded(e, 'حسین')),
  Scenario('ثبت بدهی مریم', ['به مریم بدهکارم', 'یک میلیون تومان', 'تا دو هفته دیگه'],
      verify: (e) => _verifyDebtAdded(e, 'مریم')),
  Scenario('پرداخت بدهی ممد', ['بدهی ممد رو پرداخت کردم'],
      verify: (e) => _verifyDebtInactive(e, 'ممد')),
  Scenario('تسویه بدهی علی', ['بدهی علی رو تسویه کردم'],
      verify: (e) => _verifyDebtInactive(e, 'علی')),
  Scenario('پس دادن بدهی رضا', ['بدهی رضا رو پس دادم'],
      verify: (e) => _verifyDebtInactive(e, 'رضا')),
  Scenario('کنار گذاشتن برای بدهی سارا', ['پونصد هزار برای بدهی سارا کنار بذار'],
      verify: (e) => _verifyAllocationForDebt(e, 'سارا')),

  // ── گروه ۱۰: هزینهٔ آینده (۵) — stateful ────────────────────────────────
  Scenario('سفر با خرج دو میلیون',
      ['هفته دیگه میخام برم مسافرت و دو میلیون خرج داره', 'تأیید'],
      verify: (e) => _verifyPlannedAdded(e, 1)),
  Scenario('خرید لباس عید',
      ['خرج داره خرید لباس عید یک میلیون تومان', 'تأیید'],
      verify: (e) => _verifyPlannedAdded(e, 1)),
  Scenario('تعمیر ماشین',
      ['هزینه داره تعمیر ماشین هشتصد هزار تومان', 'تأیید'],
      verify: (e) => _verifyPlannedAdded(e, 1)),
  Scenario('سفر مشهد',
      ['میخام برم سفر مشهد و سه میلیون خرج داره', 'تأیید'],
      verify: (e) => _verifyPlannedAdded(e, 1)),
  Scenario('سفر شمال ماه آینده',
      ['برنامه هزینه سفر شمال پنج میلیون تومان برای ماه آینده', 'تأیید'],
      verify: (e) => _verifyPlannedAdded(e, 1)),

  // ── گروه ۱۱: ریسک و پیش‌بینی (۵) ───────────────────────────────────────
  Scenario('ریسک مالی', ['ریسک مالی دارم؟']),
  Scenario('نکاردن فردا', ['اگه فردا کار نکنم چی میشه']),
  Scenario('سه ساعت کار امروز', ['اگه امروز ۳ ساعت کار کنم چه تاثیری داره']),
  Scenario('خطر مالی', ['خطر مالی دارم؟']),
  Scenario('چقدر عقب میفتم', ['چقدر عقب میفتم']),
];

// ── بررسی‌های اثر (state verification) ────────────────────────────────────

void _verifyTasksAdded(ScenarioEnv e, int count) {
  // فقط کارهای ثبت‌شدهٔ این سناریو باید افزوده شده باشند؛ عنوان نباید خالی باشد.
  expect(e.task.tasks.length, greaterThanOrEqualTo(count));
  for (final t in e.task.tasks) {
    expect(t.title.trim(), isNotEmpty);
  }
}

void _verifyIncomesAdded(ScenarioEnv e, int count) {
  final before = e.finance.transactions
      .where((t) => t.type == FinanceTransactionType.income)
      .length;
  expect(before, greaterThanOrEqualTo(count));
  for (final t in e.finance.transactions
      .where((t) => t.type == FinanceTransactionType.income)) {
    expect(t.amount, greaterThan(0));
  }
}

void _verifyExpensesAdded(ScenarioEnv e, int count) {
  final expenses = e.finance.transactions
      .where((t) => t.type == FinanceTransactionType.expense)
      .length;
  expect(expenses, greaterThanOrEqualTo(count));
}

void _verifyDebtAdded(ScenarioEnv e, String person) {
  expect(
    e.debt.items.any((d) => d.personName == person),
    isTrue,
    reason: 'بدهی «$person» ثبت نشده است.',
  );
  expect(e.debt.items.any((d) => d.personName == person && d.amount > 0), isTrue);
}

void _verifyDebtInactive(ScenarioEnv e, String person) {
  expect(
    e.debt.activeItems.any((d) => d.personName == person),
    isFalse,
    reason: 'بدهی «$person» هنوز فعال است.',
  );
}

void _verifyAllocationForDebt(ScenarioEnv e, String person) {
  final debt = e.debt.items.firstWhere(
    (d) => d.personName == person,
    orElse: () => throw StateError('بدهی $person یافت نشد'),
  );
  expect(
    e.allocation.items.any(
      (a) =>
          a.targetType == AllocationTargetType.debt &&
          a.targetId == debt.id &&
          a.amount > 0,
    ),
    isTrue,
    reason: 'کنارگذاری برای بدهی «$person» ثبت نشده است.',
  );
}

void _verifyPlannedAdded(ScenarioEnv e, int count) {
  expect(e.planned.activeItems.length, greaterThanOrEqualTo(count));
  for (final p in e.planned.activeItems) {
    expect(p.title.trim(), isNotEmpty);
    expect(p.targetAmount, greaterThan(0));
  }
}
