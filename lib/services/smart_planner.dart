import 'dart:math';

import '../models/scheduled_item.dart';
import '../models/task.dart';
import '../utils/persian_format.dart';

class SmartPlanner {
  const SmartPlanner();

  int priorityScore(Task task, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (task.isDone) return -999;

    var score = 0;

    // قفل دستی کاربر: همیشه مهم‌تر.
    if (task.isPinned) score += 35;

    // اهمیت ۱ تا ۵
    score += task.importance * 18;

    // مهلت انجام/فوریت
    final due = task.dueAt;
    if (due == null) {
      score += 4;
    } else {
      final hoursLeft = due.difference(current).inHours;
      if (hoursLeft < 0) {
        score += 120 + min(48, hoursLeft.abs());
      } else if (hoursLeft <= 6) {
        score += 95;
      } else if (hoursLeft <= 24) {
        score += 75;
      } else if (hoursLeft <= 72) {
        score += 45;
      } else if (hoursLeft <= 7 * 24) {
        score += 25;
      } else {
        score += 10;
      }
    }

    // کارهای کوتاه برای ایجاد momentum امتیاز می‌گیرند.
    if (task.estimatedMinutes <= 15) {
      score += 16;
    } else if (task.estimatedMinutes <= 30) {
      score += 10;
    } else if (task.estimatedMinutes >= 150) {
      score -= 12;
    }

    // هماهنگی با انرژی روز.
    score += _energyFitScore(task.energy, current.hour);

    // هرچه کار قدیمی‌تر، کمی بالاتر.
    final ageDays = current.difference(task.createdAt).inDays;
    score += min(20, ageDays * 2);

    return max(0, score);
  }

  int _energyFitScore(EnergyLevel energy, int hour) {
    final isMorning = hour >= 7 && hour <= 12;
    final isAfternoon = hour > 12 && hour <= 17;
    final isEvening = hour > 17;

    switch (energy) {
      case EnergyLevel.high:
        if (isMorning) return 12;
        if (isAfternoon) return 5;
        if (isEvening) return -8;
        return 0;
      case EnergyLevel.medium:
        if (isMorning || isAfternoon) return 8;
        return 2;
      case EnergyLevel.low:
        if (isEvening) return 10;
        return 4;
    }
  }

  String explainPriority(Task task, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final parts = <String>[];

    if (task.isPinned) parts.add('سنجاق شده');
    if (task.importance >= 4) parts.add('اهمیت بالا');
    if (task.dueAt != null) {
      final diff = task.dueAt!.difference(current);
      if (diff.inMinutes < 0) {
        parts.add('عقب‌افتاده');
      } else if (diff.inHours <= 24) {
        parts.add('مهلت انجام نزدیک');
      }
    }
    if (task.estimatedMinutes <= 30) parts.add('قابل انجام سریع');
    if (task.energy == EnergyLevel.high && current.hour <= 12) {
      parts.add('مناسب انرژی صبح');
    }
    if (parts.isEmpty) parts.add('تعادل مناسب بین اهمیت و زمان');
    return parts.join('، ');
  }

  /// تخمین زمان را با سابقه کارهای کامل‌شده بهتر می‌کند.
  int recommendedEstimate(Task task, List<Task> allTasks) {
    final history = allTasks.where((t) {
      return t.isDone &&
          t.actualMinutes != null &&
          t.actualMinutes! > 0 &&
          (t.category == task.category || _hasSharedWord(t.title, task.title));
    }).toList();

    if (history.isEmpty) return task.estimatedMinutes;

    final avgRatio = history
            .map((t) => t.actualMinutes! / max(5, t.estimatedMinutes))
            .reduce((a, b) => a + b) /
        history.length;

    final adjusted = (task.estimatedMinutes * avgRatio).round();
    return adjusted.clamp(5, 24 * 60).toInt();
  }

  bool _hasSharedWord(String a, String b) {
    final aw = a
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    final bw = b
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    return aw.intersection(bw).isNotEmpty;
  }

  List<ScheduledItem> buildTodayPlan(
    List<Task> tasks, {
    DateTime? now,
    int dayEndHour = 22,
    int breakMinutes = 10,
  }) {
    final current = now ?? DateTime.now();
    var cursor = current.add(Duration(minutes: 5 - current.minute % 5));
    final endOfDay =
        DateTime(current.year, current.month, current.day, dayEndHour);

    if (cursor.isAfter(endOfDay)) return const [];

    // چینش آگاه به مهلت: پایه امتیاز اولویت است، اما کاری که مهلتش امروز است
    // و به‌زودی می‌رسد زودتر از کارهای بلندِ بدون مهلت چیده می‌شود تا از دست
    // نرود. قبلاً فقط بر اساس priorityScore مرتب می‌شد و یک کار با مهلت
    // نزدیک ممکن بود پشت یک کار طولانیِ کم‌اهمیت‌تر جا بماند.
    final openTasks = tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) {
        final aMinutes = recommendedEstimate(a, tasks);
        final bMinutes = recommendedEstimate(b, tasks);
        return _schedulingRank(b, bMinutes, current)
            .compareTo(_schedulingRank(a, aMinutes, current));
      });

    final plan = <ScheduledItem>[];

    for (final task in openTasks) {
      final minutes = recommendedEstimate(task, tasks);
      final end = cursor.add(Duration(minutes: minutes));
      if (end.isAfter(endOfDay)) continue;

      var reason = explainPriority(task, now: current);
      // اگر مهلت امروز است و طبق این چینش به آن نمی‌رسیم، صادقانه هشدار بده.
      if (task.dueAt != null &&
          _isSameDay(task.dueAt!, current) &&
          task.dueAt!.isBefore(end)) {
        reason = '$reason؛ ممکن است به مهلت نرسی';
      }

      plan.add(ScheduledItem(
        task: task,
        start: cursor,
        end: end,
        priorityScore: priorityScore(task, now: current),
        reason: reason,
      ));

      final needsBreak = minutes >= 50;
      cursor = end.add(Duration(minutes: needsBreak ? breakMinutes : 5));
      if (cursor.isAfter(endOfDay)) break;
    }

    return plan;
  }

  /// رتبهٔ چینش یک کار در برنامهٔ امروز: امتیاز اولویت + ضریب فوریتِ مهلت.
  ///
  /// کارهای عقب‌افتاده و کارهایی که مهلتشان امروز است و زمان کمی مانده،
  /// بوست می‌گیرند تا پیش از کارهای بلندِ بدون مهلت چیده شوند.
  double _schedulingRank(Task task, int minutes, DateTime current) {
    var rank = priorityScore(task, now: current).toDouble();
    final due = task.dueAt;
    if (due == null) return rank;

    final dueToday = _isSameDay(due, current);
    if (due.isBefore(current)) {
      // عقب‌افتاده — همیشه در صدر چینش
      rank += 150;
    } else if (dueToday) {
      final hoursLeft = due.difference(current).inMinutes / 60.0;
      // هرچه زمان کمتری مانده، فوریت بیشتر
      rank += 60 + (24 - min(24, hoursLeft)) * 3;
      // اگر حتی با چیدن فوری هم به مهلت نمی‌رسد، باز هم جلوتر
      if (hoursLeft * 60 < minutes) rank += 40;
    }
    return rank;
  }

  /// گزارش «ظرفیت امروز»: مقایسهٔ حجم کار باز با پنجرهٔ باقی‌مانده،
  /// کارهایی که در برنامه جا نمی‌شوند و کارهایی که احتمالاً به مهلت امروز
  /// نمی‌رسند. برای اینکه کاربر بداند امروز چند کارش واقعاً شدنی است.
  List<String> overloadReport(
    List<Task> tasks, {
    DateTime? now,
    int dayEndHour = 22,
  }) {
    final current = now ?? DateTime.now();
    final start = current.add(Duration(minutes: 5 - current.minute % 5));
    final endOfDay =
        DateTime(current.year, current.month, current.day, dayEndHour);
    final available = endOfDay.difference(start).inMinutes;

    final open = tasks.where((t) => !t.isDone).toList();
    if (open.isEmpty) return const [];
    if (available <= 0) {
      return const ['ساعت کاری امروز تمام شده؛ کارهای باز به فردا منتقل می‌شوند.'];
    }

    final needed = open.fold<int>(0, (sum, t) => sum + recommendedEstimate(t, tasks));
    final result = <String>[];

    if (needed > available) {
      final overflow = needed - available;
      result.add(
          'حجم کار امروز ${PersianFormat.minutes(available)} جا دارد، اما حدود ${PersianFormat.minutes(needed)} کار باز داری — ${PersianFormat.minutes(overflow)} اضافه است.');
    } else {
      result.add(
          'حجم کار امروز مناسب است: حدود ${PersianFormat.minutes(needed)} کار در پنجرهٔ ${PersianFormat.minutes(available)} جای می‌گیرد.');
    }

    // کارهایی که در برنامهٔ امروز جا نشدند
    final plan = buildTodayPlan(tasks, now: current, dayEndHour: dayEndHour);
    final plannedIds = plan.map((i) => i.task.id).toSet();
    final unplanned = open.where((t) => !plannedIds.contains(t.id)).toList()
      ..sort((a, b) => priorityScore(b, now: current)
          .compareTo(priorityScore(a, now: current)));
    if (unplanned.isNotEmpty) {
      final names = unplanned
          .take(3)
          .map((t) => '«${t.title}»')
          .join('، ');
      result.add('این کارها در برنامهٔ امروز جا نشدند: $names.'
          '${unplanned.length > 3 ? ' (و ${PersianFormat.digits(unplanned.length - 3)} کار دیگر)' : ''}');
    }

    // کارهایی که طبق چینش، به مهلت امروز نمی‌رسند
    for (final item in plan) {
      final due = item.task.dueAt;
      if (due != null && _isSameDay(due, current) && due.isBefore(item.end)) {
        result.add(
            '«${item.task.title}» تا ${PersianFormat.time(due)} مهلت دارد ولی در برنامه حدود ${PersianFormat.time(item.end)} تمام می‌شود — زودتر شروعش کن یا زمانش را کم کن.');
      }
    }

    return result;
  }

  List<String> suggestions(List<Task> tasks, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final open = tasks.where((t) => !t.isDone).toList();
    final done = tasks.where((t) => t.isDone).toList();
    final result = <String>[];

    if (open.isEmpty) {
      result.add(
          'فعلاً کاری برای انجام نداری. اگر کاری ذهنت را مشغول کرده، همین الان ثبتش کن.');
      return result;
    }

    final sorted = [...open]..sort((a, b) => priorityScore(b, now: current)
        .compareTo(priorityScore(a, now: current)));
    final top = sorted.first;
    result.add(
        'بهترین کار بعدی: «${top.title}» چون ${explainPriority(top, now: current)}.');

    final overdue =
        open.where((t) => t.dueAt != null && t.dueAt!.isBefore(current)).length;
    if (overdue > 0) {
      result.add(
          '${PersianFormat.digits(overdue)} کار عقب‌افتاده داری؛ بهتر است قبل از اضافه کردن کار جدید، یکی از آن‌ها را ببندی.');
    }

    final longTasks =
        open.where((t) => t.estimatedMinutes >= 120).take(2).toList();
    for (final t in longTasks) {
      result.add(
          'کار «${t.title}» طولانی است؛ آن را به بخش‌های ۲۵ تا ۴۵ دقیقه‌ای تقسیم کن.');
    }

    final highEnergyLater = open
        .where((t) => t.energy == EnergyLevel.high && current.hour >= 18)
        .take(1)
        .toList();
    if (highEnergyLater.isNotEmpty) {
      result.add(
          'برای کارهای انرژی‌بر مثل «${highEnergyLater.first.title}» بهتر است فردا صبح زمان بگذاری.');
    }

    if (done.length >= 3) {
      final withActual = done
          .where((t) => t.actualMinutes != null && t.actualMinutes! > 0)
          .toList();
      if (withActual.isNotEmpty) {
        final ratio = withActual
                .map((t) => t.actualMinutes! / max(5, t.estimatedMinutes))
                .reduce((a, b) => a + b) /
            withActual.length;
        if (ratio > 1.25) {
          result.add(
              'معمولاً کارها بیشتر از تخمینت طول می‌کشند؛ برای کارهای بعدی حدود ${PersianFormat.digits((ratio * 100 - 100).round())}٪ زمان اضافه در نظر بگیر.');
        } else if (ratio < 0.8) {
          result.add(
              'معمولاً سریع‌تر از تخمینت کارها را تمام می‌کنی؛ می‌توانی برنامه روزانه را کمی فشرده‌تر بچینی.');
        }
      }
    }

    return result.take(5).toList();
  }

  /// یک روز از برنامهٔ هفته.
  WeekDayPlan buildDayPlanFor(
    DateTime day, {
    required List<Task> tasks,
    DateTime? now,
    int dayStartHour = 9,
    int dayEndHour = 22,
  }) {
    final reference = now ?? DateTime.now();
    final isToday = _isSameDay(day, reference);
    final start = isToday
        ? reference
        : DateTime(day.year, day.month, day.day, dayStartHour);
    final plan = buildTodayPlan(tasks, now: start, dayEndHour: dayEndHour);
    return WeekDayPlan(date: day, items: plan, isToday: isToday);
  }

  /// برنامهٔ سادهٔ ۷ روز آینده.
  List<WeekDayPlan> buildWeekPlan(
    List<Task> tasks, {
    DateTime? now,
    int days = 7,
    int dayStartHour = 9,
    int dayEndHour = 22,
  }) {
    final current = now ?? DateTime.now();
    final result = <WeekDayPlan>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(current.year, current.month, current.day)
          .add(Duration(days: i));
      final plan = buildDayPlanFor(
        day,
        tasks: tasks,
        now: current,
        dayStartHour: dayStartHour,
        dayEndHour: dayEndHour,
      );
      result.add(plan);
    }
    return result;
  }

  /// بهترین بازه‌های آزاد امروز برای کار عمیق (بازه‌های ≥ ۴۵ دقیقه).
  ///
  /// بازه‌ها از شکاف‌های برنامهٔ امروز پیدا می‌شوند و بر اساس
  /// تعداد کارهای انرژی‌برِ نزدیک، امتیاز می‌گیرند.
  List<DeepWorkWindow> bestDeepWorkWindows(
    List<Task> tasks, {
    DateTime? now,
    int dayStartHour = 7,
    int dayEndHour = 22,
    int minWindowMinutes = 45,
  }) {
    final current = now ?? DateTime.now();
    final startOfDay =
        DateTime(current.year, current.month, current.day, dayStartHour);
    final endOfDay =
        DateTime(current.year, current.month, current.day, dayEndHour);

    // بازهٔ کاری شروع = الان یا ابتدای روز، هرکدام دیرتر.
    final dayBegin = current.isBefore(startOfDay) ? startOfDay : current;
    if (dayBegin.isAfter(endOfDay)) return const [];

    final plan = buildTodayPlan(tasks, now: dayBegin, dayEndHour: dayEndHour);
    final windows = <DeepWorkWindow>[];

    // شکاف قبل از اولین کار
    var cursor = dayBegin;
    for (final item in plan) {
      if (item.start.difference(cursor).inMinutes >= minWindowMinutes) {
        windows.add(DeepWorkWindow(
          start: cursor,
          end: item.start,
          reason: 'قبل از «${item.task.title}»',
        ));
      }
      cursor = item.end.isAfter(cursor) ? item.end : cursor;
    }

    // شکاف بعد از آخرین کار
    if (endOfDay.difference(cursor).inMinutes >= minWindowMinutes) {
      windows.add(DeepWorkWindow(
        start: cursor,
        end: endOfDay,
        reason: 'پایان روز',
      ));
    }

    if (windows.isEmpty) return const [];

    // امتیاز هر پنجره: تعداد کارهای انرژی‌بر + طول پنجره
    final scores = <DeepWorkWindow, int>{};
    final open = tasks.where((t) => !t.isDone).toList();
    for (final window in windows) {
      var score = 0;
      for (final task in open) {
        if (task.energy == EnergyLevel.high) score += 2;
        final due = task.dueAt;
        if (due != null && due.difference(current).inHours <= 48) score += 1;
      }
      score += window.end.difference(window.start).inMinutes ~/ 30;
      scores[window] = score;
    }
    windows.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return windows.take(2).toList();
  }

  /// برنامهٔ جبران برای کارهای عقب‌افتاده: ترتیب پیشنهادی و جمع زمان.
  List<String> catchUpPlan(List<Task> tasks, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final overdue = tasks
        .where(
            (t) => !t.isDone && t.dueAt != null && t.dueAt!.isBefore(current))
        .toList()
      ..sort((a, b) => priorityScore(b, now: current)
          .compareTo(priorityScore(a, now: current)));
    if (overdue.isEmpty) return const [];

    final lines = <String>[];
    final total =
        overdue.fold<int>(0, (sum, t) => sum + recommendedEstimate(t, tasks));
    lines.add(
        'برای جبران ${PersianFormat.digits(overdue.length)} کار عقب‌افتاده، این ترتیب را پیشنهاد می‌کنم:');
    lines.addAll(overdue.take(5).map((t) =>
        '• ${t.title} — حدود ${PersianFormat.minutes(recommendedEstimate(t, tasks))}'));
    lines.add('جمع کل: حدود ${PersianFormat.minutes(total)}.');

    final longOnes = overdue
        .where((t) => recommendedEstimate(t, tasks) >= 120)
        .take(2)
        .toList();
    if (longOnes.isNotEmpty) {
      lines.add(
          'توصیه: کارهای طولانی را به بخش‌های ۲۵ تا ۴۵ دقیقه‌ای تقسیم کن و بینشان استراحت کوتاه بگذار.');
    }
    return lines;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// یک روز از برنامهٔ هفته.
class WeekDayPlan {
  const WeekDayPlan({
    required this.date,
    required this.items,
    required this.isToday,
  });

  final DateTime date;
  final List<ScheduledItem> items;
  final bool isToday;
}

/// پنجرهٔ زمانی پیشنهادی برای کار عمیق.
class DeepWorkWindow {
  const DeepWorkWindow({
    required this.start,
    required this.end,
    required this.reason,
  });

  final DateTime start;
  final DateTime end;
  final String reason;
}
