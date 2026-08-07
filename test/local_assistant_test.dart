import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_day_planner/models/debt_item.dart';
import 'package:smart_day_planner/models/finance_transaction.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/models/work_time_settings.dart';
import 'package:smart_day_planner/services/finance_insights_service.dart';
import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/local_assistant.dart';
import 'package:smart_day_planner/services/work_learning_service.dart';

Task _task({
  required String id,
  required String title,
  int importance = 3,
  int estimatedMinutes = 30,
  EnergyLevel energy = EnergyLevel.medium,
  DateTime? dueAt,
  TaskStatus status = TaskStatus.todo,
}) {
  return Task(
    id: id,
    title: title,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    importance: importance,
    estimatedMinutes: estimatedMinutes,
    energy: energy,
    dueAt: dueAt,
    status: status,
  );
}

List<Task> _sampleTasks() => [
      _task(
        id: '1',
        title: 'تماس با مشتری',
        importance: 5,
        estimatedMinutes: 45,
        energy: EnergyLevel.high,
        dueAt: DateTime.now().add(const Duration(hours: 3)),
      ),
      _task(
        id: '2',
        title: 'ثبت گزارش',
        importance: 2,
        estimatedMinutes: 15,
        dueAt: DateTime.now().add(const Duration(days: 2)),
      ),
      _task(
        id: '3',
        title: 'پاسخ به ایمیل',
        importance: 4,
        estimatedMinutes: 20,
        dueAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: TaskStatus.todo,
      ),
    ];

void main() {
  final assistant = RuleBasedLocalAssistant();

  group('RuleBasedLocalAssistant: تشخیص قصد', () {
    test('سلام → پاسخ سلام', () async {
      final answer =
          await assistant.generate(prompt: 'سلام', tasks: _sampleTasks());
      expect(answer, contains('سلام'));
    });

    test('الان چی کار کنم → پیشنهاد بهترین کار بعدی', () async {
      final answer = await assistant.generate(
          prompt: 'الان چی کار کنم؟', tasks: _sampleTasks());
      expect(answer, contains('تماس با مشتری'));
    });

    test('برنامه امروز → برنامهٔ زمانی', () async {
      // ساعت را به صبحِ امروز ثابت می‌کنیم تا صرف‌نظر از ساعتی که تست اجرا
      // می‌شود، برنامهٔ امروز قابل چیدن باشد (رفع flaky در اواخر شب).
      final morning = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day, 9);
      final morningAssistant = RuleBasedLocalAssistant(now: () => morning);
      final answer = await morningAssistant.generate(
          prompt: 'برنامه امروزمو بچین', tasks: _sampleTasks());
      expect(answer, contains('برنامهٔ امروز'));
      expect(answer, contains('تا'));
    });

    test('چی عقب مونده → کارهای عقب‌افتاده', () async {
      final answer = await assistant.generate(
          prompt: 'چی عقب مونده؟', tasks: _sampleTasks());
      expect(answer, contains('پاسخ به ایمیل'));
    });

    test('ریسک → هشدار کارهای عقب‌افتاده', () async {
      final answer =
          await assistant.generate(prompt: 'ریسک دارم؟', tasks: _sampleTasks());
      expect(answer, contains('عقب'));
    });

    test('راهنما → لیست قابلیت‌ها', () async {
      final answer = await assistant.generate(
          prompt: 'چه کارهایی بلدی؟', tasks: _sampleTasks());
      expect(answer, contains('الان چی کار کنم'));
      expect(answer, contains('برنامه امروز'));
    });

    test('جبران → برنامهٔ جبران برای کار عقب‌افتاده', () async {
      final answer =
          await assistant.generate(prompt: 'جبران کن', tasks: _sampleTasks());
      expect(answer, contains('جبران'));
    });

    test('متن خالی → خلاصهٔ روز', () async {
      final answer =
          await assistant.generate(prompt: '', tasks: _sampleTasks());
      expect(answer, contains('خلاصهٔ امروز'));
    });

    test('متن نامربوط → خلاصهٔ روز با پیشنهاد', () async {
      final answer = await assistant.generate(
          prompt: 'دربارهٔ آب و هوا بگو', tasks: _sampleTasks());
      expect(answer, contains('خلاصهٔ امروز'));
    });

    test('ممنون → تشکر', () async {
      final answer =
          await assistant.generate(prompt: 'ممنون', tasks: _sampleTasks());
      expect(answer, contains('خواهش'));
    });
  });

  group('RuleBasedLocalAssistant: با زمینهٔ مالی', () {
    late FinanceRepository financeRepo;
    late RuleBasedLocalAssistant financeAware;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      financeRepo = FinanceRepository();
      await financeRepo.load();

      final now = DateTime.now();
      await financeRepo.add(FinanceTransaction(
        id: 'i1',
        type: FinanceTransactionType.income,
        amount: 3000000,
        createdAt: now.subtract(const Duration(days: 1)),
        minutesWorked: 300,
      ));
      await financeRepo.add(FinanceTransaction(
        id: 'i2',
        type: FinanceTransactionType.income,
        amount: 1500000,
        createdAt: now.subtract(const Duration(days: 3)),
        minutesWorked: 150,
      ));
      await financeRepo.add(FinanceTransaction(
        id: 'e1',
        type: FinanceTransactionType.expense,
        amount: 200000,
        createdAt: now.subtract(const Duration(days: 2)),
        category: 'خوراک',
      ));
      await financeRepo.add(FinanceTransaction(
        id: 'e2',
        type: FinanceTransactionType.expense,
        amount: 250000,
        createdAt: now.subtract(const Duration(days: 40)),
        category: 'خوراک',
      ));

      financeAware = RuleBasedLocalAssistant(
        context: AssistantContext(
          finance: financeRepo,
          insights: const FinanceInsightsService(),
        ),
      );
    });

    test('چقدر درآمد دارم → پیش‌بینی بر اساس درآمد ساعتی', () async {
      final answer = await financeAware
          .generate(prompt: 'چقدر درآمد دارم؟', tasks: const []);
      expect(answer, contains('درآمد ساعتی'));
      expect(answer, contains('تومان'));
    });

    test('وضعیت مالیم → توصیهٔ مالی', () async {
      final answer = await financeAware
          .generate(prompt: 'وضعیت مالیم چطوره؟', tasks: const []);
      expect(answer, contains('درآمد'));
      expect(answer, contains('خرج'));
    });

    test('بودجه → وضعیت خرج این ماه', () async {
      final answer = await financeAware
          .generate(prompt: 'بودجه‌ام چطوره؟', tasks: const []);
      expect(answer, contains('خرج این ماه'));
    });

    test('ریسک → شامل ریسک مالی هم هست', () async {
      final answer = await financeAware.generate(
          prompt: 'ریسک مالی دارم؟', tasks: _sampleTasks());
      expect(answer, contains('عقب'));
    });
  });

  group('RuleBasedLocalAssistant: با ساعت کاری (TimeAwarePlanner)', () {
    final availabilityAware = RuleBasedLocalAssistant(
      context: AssistantContext(
        // همهٔ روزها باز، ساعت کاری ۸ تا ۱۷
        availability: const WorkTimeSettings(
          startHour: 8,
          endHour: 17,
          offWeekdays: {},
          breakMinutesPerHour: 10,
        ),
      ),
    );

    test('برنامهٔ امروز ساعت کاری کاربر را رعایت می‌کند', () async {
      final answer = await availabilityAware.generate(
          prompt: 'برنامه امروزمو بچین', tasks: _sampleTasks());
      expect(answer, contains('با رعایت ساعت کاری'));
      expect(answer, contains('۸ تا ۱۷'));
    });
  });

  group('RuleBasedLocalAssistant: حل مسئلهٔ پرداخت بدهی', () {
    final now = DateTime.now();
    final debts = [
      DebtItem(
        id: 'd1',
        type: DebtType.debt,
        personName: 'علی',
        amount: 20000000,
        dueAt: now.add(const Duration(days: 30)),
        createdAt: now,
      ),
      DebtItem(
        id: 'd2',
        type: DebtType.debt,
        personName: 'محمد',
        amount: 5000000,
        dueAt: now.add(const Duration(days: 30)),
        createdAt: now,
      ),
      DebtItem(
        id: 'd3',
        type: DebtType.debt,
        personName: 'حسن',
        amount: 1000000,
        dueAt: now.add(const Duration(days: 30)),
        createdAt: now,
      ),
    ];

    // پروفایل: ۳۰۰ هزار در ساعت، ۲ ساعت کار در روز → توان ۶۰۰ هزار/روز
    final profile = WorkProfile(
      avgDailyWorkMinutes: 120,
      avgHourlyRate: 300000,
      dailyEarningCapacity: 600000,
      historyDays: 5,
      sampleCount: 6,
    );

    final repaymentAssistant = RuleBasedLocalAssistant(
      context: AssistantContext(
        debts: debts,
        workProfile: profile,
      ),
    );

    test('برنامهٔ پرداخت → مجموع، اولویت و نیاز روزانه', () async {
      final answer = await repaymentAssistant.generate(
          prompt: 'برنامه پرداخت بدهی‌ها چیه؟', tasks: const []);
      // مجموع ۲۶ میلیون
      expect(answer, contains('۲۶٬۰۰۰٬۰۰۰'));
      // اولویت‌بندی
      expect(answer, contains('اولویت پرداخت'));
      expect(answer, contains('علی'));
      expect(answer, contains('محمد'));
      expect(answer, contains('حسن'));
      // نیاز روزانه: ۲۶ میلیون / ۳۰ روز ≈ ۸۶۷ هزار
      expect(answer, contains('روزی'));
      // ساعت لازم با درآمد ساعتی
      expect(answer, contains('ساعت کار در روز'));
    });

    test('بدون بدهی → پیام مناسب', () async {
      final empty = RuleBasedLocalAssistant(
        context: const AssistantContext(),
      );
      final answer =
          await empty.generate(prompt: 'برنامه پرداخت بدهی', tasks: const []);
      expect(answer, contains('بدهی فعالی نداری'));
    });

    test('پرسش «چقدر کار کنم تا قسط‌ها تموم شه» → برنامهٔ پرداخت', () async {
      final answer = await repaymentAssistant.generate(
          prompt: 'چقدر کار کنم تا قسط‌هام تموم شه؟', tasks: const []);
      expect(answer, contains('مجموع بدهی‌هایت'));
      expect(answer, contains('ساعت کار در روز'));
    });
  });
}
