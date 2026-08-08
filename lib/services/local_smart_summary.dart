import '../models/task.dart';
import '../utils/persian_format.dart';
import 'persian_nlu.dart';

/// خلاصهٔ هوشمندِ کاملاً آفلاین از وضعیت کاربر.
///
/// وقتی پرسش کاربر دقیقاً روی یک intent شناخته‌شده منطبق نیست، به‌جای پاسخ
/// کلی یا نیاز به آنلاین، این ماژول با تحلیل سبک متن و داده‌های واقعی برنامه
/// یک پاسخ مفید و کوتاه می‌سازد.
class LocalSmartSummary {
  const LocalSmartSummary._();

  /// یک پاسخ محلی بر اساس نوع سؤال و داده‌های واقعی.
  /// اگر نتوان پاسخ معناداری ساخت، null برمی‌گرداند (تا لایهٔ بعدی تصمیم بگیرد).
  static String? answer({
    required String text,
    required List<Task> tasks,
    int? overdueCount,
    int? totalTasks,
    double? completionRate,
  }) {
    final qType = PersianQuestionClassifier.classify(text);
    final openTasks = tasks.where((t) => !t.isDone).toList();
    final doneTasks = tasks.where((t) => t.isDone).toList();

    switch (qType) {
      case QuestionType.what:
      case QuestionType.planning:
        return _planningAnswer(openTasks, doneTasks, overdue: overdueCount);
      case QuestionType.money:
        // سؤالات مالی به موتور مالی/حافظه سپرده می‌شوند.
        return null;
      case QuestionType.time:
        return _timeAnswer(openTasks);
      case QuestionType.why:
        return 'من بر اساس داده‌های واقعی برنامه‌ریزی می‌کنم: مهلت‌ها، اهمیت و '
            'انرژی مورد نیاز کارها. اگر دلیل خاصی مد نظرته، واضح‌تر بپرس.';
      case QuestionType.greeting:
        return null;
      case QuestionType.unknown:
        // برای پرسش‌های کوتاه ناشناخته، یک خلاصهٔ وضعیت بده.
        if (text.trim().length <= 12) return _statusSnapshot(openTasks, doneTasks);
        return null;
    }
  }

  static String _planningAnswer(
    List<Task> open,
    List<Task> done, {
    int? overdue,
  }) {
    if (open.isEmpty) {
      return 'هیچ کار بازی نداری ✨ فرصت خوبی برای استراحت یا برنامه‌ریزی کارهای جدید است.';
    }
    final sorted = [...open]..sort((a, b) {
        final sa = _priorityScore(a);
        final sb = _priorityScore(b);
        return sb.compareTo(sa);
      });
    final top = sorted.take(3).toList();
    final overdueCount = overdue ??
        open.where((t) => t.dueAt != null && t.dueAt!.isBefore(DateTime.now())).length;

    final buf = StringBuffer('📋 خلاصهٔ کارها:\n');
    for (var i = 0; i < top.length; i++) {
      final t = top[i];
      final bullet = i == 0 ? '🎯' : (i == 1 ? '🥈' : '🥉');
      final due = _formatDue(t);
      buf.writeln('$bullet ${t.title}$due');
    }
    if (overdueCount > 0) {
      buf.writeln('⚠️ $overdueCount کار از مهلت گذشته است.');
    }
    final totalMin = open.fold<int>(0, (s, t) => s + t.estimatedMinutes);
    buf.write('در مجموع ${PersianFormat.minutes(totalMin)} کار باقی مانده و '
        '${PersianFormat.digits(done.length)} کار انجام شده است.');
    return buf.toString();
  }

  static String _timeAnswer(List<Task> open) {
    final now = DateTime.now();
    final withDue = open.where((t) => t.dueAt != null).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (withDue.isEmpty) {
      return 'هیچ کار زمان‌بندی‌شده‌ای نداری. می‌تونی یک کار با مهلت اضافه کنی.';
    }
    final next = withDue.first;
    final diff = next.dueAt!.difference(now);
    final when = _relativeTime(diff);
    return 'نزدیک‌ترین کار «${next.title}» است و $when سررسیدش می‌شود.';
  }

  static String _statusSnapshot(List<Task> open, List<Task> done) {
    if (open.isEmpty) {
      return 'همه‌چیز مرتب است؛ کاری برای انجام نداری ✅';
    }
    final total = open.length + done.length;
    final pct = total == 0 ? 0 : ((done.length / total) * 100).round();
    final urgent = open
        .where((t) =>
            t.dueAt != null &&
            t.dueAt!.isBefore(DateTime.now().add(const Duration(hours: 24))))
        .length;
    return '🔔 ${PersianFormat.digits(open.length)} کار باز داری '
        '(${PersianFormat.digits(pct)}٪ انجام شده)'
        '${urgent > 0 ? ' و $urgent کار نزدیک مهلت است' : ''}.';
  }

  /// امتیاز اولویت ساده: اهمیت + نزدیکی مهلت + انرژی مورد نیاز.
  static int _priorityScore(Task t) {
    var score = t.importance * 10;
    final due = t.dueAt;
    if (due != null) {
      final hours = due.difference(DateTime.now()).inHours;
      if (hours < 0) {
        score += 50; // گذشته از مهلت
      } else if (hours < 24) {
        score += 30;
      } else if (hours < 72) {
        score += 15;
      }
    }
    if (t.isPinned) score += 20;
    if (t.energy == EnergyLevel.high) score += 5;
    return score;
  }

  static String _formatDue(Task t) {
    final due = t.dueAt;
    if (due == null) return '';
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) {
      final late = diff.inDays.abs();
      return late == 0 ? ' (امروز مهلتش بود)' : ' (${PersianFormat.digits(late)} روز تأخیر)';
    }
    if (diff.inDays == 0) return ' (امروز)';
    if (diff.inDays == 1) return ' (فردا)';
    return ' (${PersianFormat.digits(diff.inDays)} روز دیگر)';
  }

  static String _relativeTime(Duration d) {
    if (d.isNegative) {
      final h = d.inHours.abs();
      return h == 0 ? 'همین حالا' : '${PersianFormat.digits(h)} ساعت پیش';
    }
    if (d.inMinutes < 60) return '${PersianFormat.digits(d.inMinutes)} دقیقه دیگر';
    if (d.inHours < 24) return '${PersianFormat.digits(d.inHours)} ساعت دیگر';
    return '${PersianFormat.digits(d.inDays)} روز دیگر';
  }
}
