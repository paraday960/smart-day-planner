import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_day_planner/services/finance_repository.dart';
import 'package:smart_day_planner/services/smart_planner_agent.dart';
import 'package:smart_day_planner/services/task_repository.dart';
import 'package:smart_day_planner/services/work_learning_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmartScenarioMemory.instance.reset();
  });

  final repos = _Repos();

  test('درخواست عادی (غیرسناریو) پیام خالی برمی‌گرداند', () async {
    final agent = SmartPlannerAgent(onlineBackend: null);
    final result = await agent.handle(
      rawText: 'سلام',
      taskRepository: repos.task,
      financeRepository: repos.finance,
      workProfile: WorkProfile.empty,
    );
    expect(result.message, isEmpty);
  });

  test('سناریوی هدف مالی + رویداد، برنامه اجرا می‌کند', () async {
    final agent = SmartPlannerAgent(onlineBackend: null);
    final result = await agent.handle(
      rawText: 'من امروز یک میلیون پول دارم و هفته دیگه باید با دوست دخترم برم بیرون',
      taskRepository: repos.task,
      financeRepository: repos.finance,
      workProfile: WorkProfile.empty,
    );
    expect(result.message, isNotEmpty);
    // یک کار «قرار» باید ساخته شده باشد.
    final tasks = repos.task.tasks;
    expect(tasks.any((t) => t.title.contains('دوست')), isTrue);
  });

  test('یادگیری: سناریوی مشابه دوم بدون هوش آنلاین با reused=true اجرا می‌شود', () async {
    final agent = SmartPlannerAgent(onlineBackend: null);
    final first = await agent.handle(
      rawText: 'من یک میلیون دارم و هفته بعد باید با دوستم برم بیرون',
      taskRepository: repos.task,
      financeRepository: repos.finance,
      workProfile: WorkProfile.empty,
    );
    expect(first.message, isNotEmpty);
    expect(first.reused, isFalse);

    // سناریوی مشابه با مبلغ متفاوت اما همان اثر انگشت → reuse
    final second = await agent.handle(
      rawText: 'من دو میلیون دارم و هفته دیگه باید با دوستم برم',
      taskRepository: repos.task,
      financeRepository: repos.finance,
      workProfile: WorkProfile.empty,
    );
    expect(second.message, isNotEmpty);
    expect(second.reused, isTrue);
  });
}

class _Repos {
  _Repos() {
    task = TaskRepository();
    finance = FinanceRepository();
  }
  late final TaskRepository task;
  late final FinanceRepository finance;
}
