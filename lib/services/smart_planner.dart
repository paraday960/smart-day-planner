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
    if (task.energy == EnergyLevel.high && current.hour <= 12) parts.add('مناسب انرژی صبح');
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
    final aw = a.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final bw = b.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
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
    final endOfDay = DateTime(current.year, current.month, current.day, dayEndHour);

    if (cursor.isAfter(endOfDay)) return const [];

    final openTasks = tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) => priorityScore(b, now: current).compareTo(priorityScore(a, now: current)));

    final plan = <ScheduledItem>[];

    for (final task in openTasks) {
      final minutes = recommendedEstimate(task, tasks);
      final end = cursor.add(Duration(minutes: minutes));
      if (end.isAfter(endOfDay)) continue;

      plan.add(ScheduledItem(
        task: task,
        start: cursor,
        end: end,
        priorityScore: priorityScore(task, now: current),
        reason: explainPriority(task, now: current),
      ));

      final needsBreak = minutes >= 50;
      cursor = end.add(Duration(minutes: needsBreak ? breakMinutes : 5));
      if (cursor.isAfter(endOfDay)) break;
    }

    return plan;
  }

  List<String> suggestions(List<Task> tasks, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final open = tasks.where((t) => !t.isDone).toList();
    final done = tasks.where((t) => t.isDone).toList();
    final result = <String>[];

    if (open.isEmpty) {
      result.add('فعلاً کاری برای انجام نداری. اگر کاری ذهنت را مشغول کرده، همین الان ثبتش کن.');
      return result;
    }

    final sorted = [...open]..sort((a, b) => priorityScore(b, now: current).compareTo(priorityScore(a, now: current)));
    final top = sorted.first;
    result.add('بهترین کار بعدی: «${top.title}» چون ${explainPriority(top, now: current)}.');

    final overdue = open.where((t) => t.dueAt != null && t.dueAt!.isBefore(current)).length;
    if (overdue > 0) {
      result.add('${PersianFormat.digits(overdue)} کار عقب‌افتاده داری؛ بهتر است قبل از اضافه کردن کار جدید، یکی از آن‌ها را ببندی.');
    }

    final longTasks = open.where((t) => t.estimatedMinutes >= 120).take(2).toList();
    for (final t in longTasks) {
      result.add('کار «${t.title}» طولانی است؛ آن را به بخش‌های ۲۵ تا ۴۵ دقیقه‌ای تقسیم کن.');
    }

    final highEnergyLater = open.where((t) => t.energy == EnergyLevel.high && current.hour >= 18).take(1).toList();
    if (highEnergyLater.isNotEmpty) {
      result.add('برای کارهای انرژی‌بر مثل «${highEnergyLater.first.title}» بهتر است فردا صبح زمان بگذاری.');
    }

    if (done.length >= 3) {
      final withActual = done.where((t) => t.actualMinutes != null && t.actualMinutes! > 0).toList();
      if (withActual.isNotEmpty) {
        final ratio = withActual
                .map((t) => t.actualMinutes! / max(5, t.estimatedMinutes))
                .reduce((a, b) => a + b) /
            withActual.length;
        if (ratio > 1.25) {
          result.add('معمولاً کارها بیشتر از تخمینت طول می‌کشند؛ برای کارهای بعدی حدود ${PersianFormat.digits((ratio * 100 - 100).round())}٪ زمان اضافه در نظر بگیر.');
        } else if (ratio < 0.8) {
          result.add('معمولاً سریع‌تر از تخمینت کارها را تمام می‌کنی؛ می‌توانی برنامه روزانه را کمی فشرده‌تر بچینی.');
        }
      }
    }

    return result.take(5).toList();
  }
}
