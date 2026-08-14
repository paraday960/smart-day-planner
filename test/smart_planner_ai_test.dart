import 'package:flutter_test/flutter_test.dart';
import 'package:smart_day_planner/models/task.dart';
import 'package:smart_day_planner/services/smart_planner.dart';

Task _task({
  required String id,
  required String title,
  int importance = 3,
  int estimatedMinutes = 30,
  EnergyLevel energy = EnergyLevel.medium,
  DateTime? dueAt,
  TaskStatus status = TaskStatus.todo,
  bool isPinned = false,
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
    isPinned: isPinned,
  );
}

void main() {
  const planner = SmartPlanner();
  // ساعت را به صبحِ امروز ثابت می‌کنیم تا تست‌های «برنامهٔ امروز/هفته»
  // مستقل از ساعتی که تست اجرا می‌شود پایدار باشند (رفع flaky در اواخر شب).
  final now = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day, 9);

  group('buildWeekPlan', () {
    test('۷ روز برنامه می‌سازد و روز جاری را مشخص می‌کند', () {
      final tasks = [_task(id: '1', title: 'کار مهم', importance: 5)];
      final week = planner.buildWeekPlan(tasks, now: now);

      expect(week.length, 7);
      expect(week.where((d) => d.isToday).length, 1);
      expect(week.first.date, DateTime(now.year, now.month, now.day));
    });

    test('کارهای باز در برنامهٔ روزها می‌آیند', () {
      final tasks = [
        _task(id: '1', title: 'کار الف', importance: 5, estimatedMinutes: 30),
        _task(id: '2', title: 'کار ب', status: TaskStatus.done),
      ];
      final week = planner.buildWeekPlan(tasks, now: now);
      final today = week.firstWhere((d) => d.isToday);

      expect(today.items.map((i) => i.task.title), contains('کار الف'));
      expect(today.items.map((i) => i.task.title), isNot(contains('کار ب')));
    });
  });

  group('bestDeepWorkWindows', () {
    test('با برنامهٔ شلوغ، پنجره‌های آزاد پیدا می‌شود', () {
      // صبح ساعت ۹ با دو کار که تا ظهر پر می‌شوند
      final morning9 = DateTime(now.year, now.month, now.day, 9);
      final tasks = [
        _task(
            id: '1',
            title: 'کار سنگین',
            importance: 5,
            estimatedMinutes: 90,
            energy: EnergyLevel.high),
        _task(id: '2', title: 'کار متوسط', importance: 4, estimatedMinutes: 60),
      ];
      final windows = planner.bestDeepWorkWindows(tasks, now: morning9);

      expect(windows, isNotEmpty);
      for (final w in windows) {
        expect(w.end.difference(w.start).inMinutes, greaterThanOrEqualTo(45));
      }
    });

    test('بعد از پایان روز هیچ پنجره‌ای نیست', () {
      final lateNight = DateTime(now.year, now.month, now.day, 23);
      final windows = planner.bestDeepWorkWindows(const [], now: lateNight);
      expect(windows, isEmpty);
    });
  });

  group('catchUpPlan', () {
    test('کار عقب‌افتاده → ترتیب جبران با زمان', () {
      final tasks = [
        _task(
            id: '1',
            title: 'گزارش معوق',
            importance: 5,
            estimatedMinutes: 60,
            dueAt: now.subtract(const Duration(hours: 5))),
        _task(
            id: '2',
            title: 'کار عادی',
            importance: 2,
            dueAt: now.add(const Duration(days: 3))),
      ];
      final plan = planner.catchUpPlan(tasks, now: now);

      expect(plan, isNotEmpty);
      expect(plan.join('\n'), contains('گزارش معوق'));
      expect(plan.join('\n'), contains('جمع کل'));
    });

    test('بدون کار عقب‌افتاده → خالی', () {
      final tasks = [
        _task(
            id: '1',
            title: 'کار عادی',
            importance: 3,
            dueAt: now.add(const Duration(days: 1))),
      ];
      expect(planner.catchUpPlan(tasks, now: now), isEmpty);
    });
  });

  group('buildTodayPlan چینش آگاه به مهلت', () {
    test('کار با مهلت نزدیک امروز پیش از کار بلندِ بدون مهلت چیده می‌شود', () {
      final morning = DateTime(now.year, now.month, now.day, 9);
      final tasks = [
        _task(
            id: '1',
            title: 'کار بلند بی‌مهلت',
            importance: 5,
            estimatedMinutes: 180,
            energy: EnergyLevel.high),
        _task(
            id: '2',
            title: 'کار فوری',
            importance: 2,
            estimatedMinutes: 20,
            dueAt: morning.add(const Duration(hours: 2))),
      ];
      final plan = planner.buildTodayPlan(tasks, now: morning);
      expect(plan, isNotEmpty);
      // کار فوری باید اول چیده شود، نه کار بلند بی‌مهلت
      expect(plan.first.task.title, 'کار فوری');
    });

    test('کار عقب‌افتاده همیشه در صدر چینش است', () {
      final morning = DateTime(now.year, now.month, now.day, 9);
      final tasks = [
        _task(id: '1', title: 'کار عادی', importance: 5, estimatedMinutes: 60),
        _task(
            id: '2',
            title: 'کار عقب‌افتاده',
            importance: 1,
            estimatedMinutes: 15,
            dueAt: morning.subtract(const Duration(hours: 3))),
      ];
      final plan = planner.buildTodayPlan(tasks, now: morning);
      expect(plan.first.task.title, 'کار عقب‌افتاده');
    });
  });

  group('overloadReport', () {
    test('وقتی حجم کار از پنجرهٔ روز بیشتر باشد، اضافه بودن را گزارش می‌دهد', () {
      final morning = DateTime(now.year, now.month, now.day, 9);
      final tasks = [
        _task(id: '1', title: 'کار یک', importance: 4, estimatedMinutes: 60),
        _task(id: '2', title: 'کار دو', importance: 4, estimatedMinutes: 60),
        _task(id: '3', title: 'کار سه', importance: 4, estimatedMinutes: 60),
        _task(id: '4', title: 'کار چهار', importance: 4, estimatedMinutes: 60),
        _task(id: '5', title: 'کار پنج', importance: 4, estimatedMinutes: 60),
        _task(id: '6', title: 'کار شش', importance: 4, estimatedMinutes: 60),
        _task(id: '7', title: 'کار هفت', importance: 4, estimatedMinutes: 60),
        _task(id: '8', title: 'کار هشت', importance: 4, estimatedMinutes: 60),
        _task(id: '9', title: 'کار نه', importance: 4, estimatedMinutes: 60),
        _task(id: '10', title: 'کار ده', importance: 4, estimatedMinutes: 60),
        _task(id: '11', title: 'کار یازده', importance: 4, estimatedMinutes: 60),
        _task(id: '12', title: 'کار دوازده', importance: 4, estimatedMinutes: 60),
        _task(id: '13', title: 'کار سیزده', importance: 4, estimatedMinutes: 60),
        _task(id: '14', title: 'کار چهارده', importance: 4, estimatedMinutes: 60),
      ];
      final report = planner.overloadReport(tasks, now: morning);
      expect(report, isNotEmpty);
      expect(report.join('\n'), contains('اضافه است'));
      expect(report.join('\n'), contains('جا نشدند'));
    });

    test('حجم کم → پیام «مناسب است» و بدون اخطار جا ماندن', () {
      final morning = DateTime(now.year, now.month, now.day, 9);
      final tasks = [
        _task(id: '1', title: 'کار کوتاه', importance: 3, estimatedMinutes: 20),
      ];
      final report = planner.overloadReport(tasks, now: morning);
      expect(report.join('\n'), contains('مناسب است'));
      expect(report.join('\n'), isNot(contains('جا نشدند')));
    });

    test('کار عقب‌افتاده نزدیک به مهلت امروز → هشدار دیر تمام شدن', () {
      final morning = DateTime(now.year, now.month, now.day, 9);
      final tasks = [
        _task(
            id: '1',
            title: 'کار با مهلت امروز',
            importance: 3,
            estimatedMinutes: 90,
            dueAt: morning.add(const Duration(hours: 1))),
      ];
      final report = planner.overloadReport(tasks, now: morning);
      expect(report.join('\n'), contains('زودتر شروعش کن'));
    });
  });

  group('priorityScore', () {
    test('کار عقب‌افتاده امتیاز بالایی دارد', () {
      final overdue = _task(
          id: '1',
          title: 'معوق',
          dueAt: now.subtract(const Duration(hours: 1)));
      final normal = _task(
          id: '2', title: 'عادی', dueAt: now.add(const Duration(days: 5)));
      expect(planner.priorityScore(overdue, now: now),
          greaterThan(planner.priorityScore(normal, now: now)));
    });

    test('کار سنجاق‌شده امتیاز می‌گیرد', () {
      final pinned = _task(id: '1', title: 'سنجاق', isPinned: true);
      final normal = _task(id: '2', title: 'عادی');
      expect(planner.priorityScore(pinned, now: now),
          greaterThan(planner.priorityScore(normal, now: now)));
    });
  });
}

