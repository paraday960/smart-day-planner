import 'persian_nlu.dart';

/// نتیجهٔ تصمیم مسیریاب بین هوش محلی و آنلاین.
enum RouteTarget {
  /// هوش محلی به‌تنهایی کافی است.
  localOnly,

  /// اول محلی امتحان شود؛ اگر کاربر بازنویسی کرد، آنلاین صدا زده شود.
  localFirst,

  /// مستقیماً آنلاین صدا زده شود (سؤال باز/پیچیده).
  online,
}

/// تصمیم‌گیرندهٔ بین هوش محلی و آنلاین.
///
/// این کلاس کاملاً مستقل از UI و Flutter است و صرفاً بر اساس ویژگی‌های متن
/// و تاریخچهٔ یادگیریِ موفق/ناموفق محلی تصمیم می‌گیرد.
class LocalOnlineRouter {
  LocalOnlineRouter({
    this.confidenceThreshold = 0.8,
    this.maxLocalLength = 60,
  });

  /// حداقل اطمینان محلی برای پاسخ بدون مراجعه به آنلاین.
  final double confidenceThreshold;

  /// سؤالات طولانی‌تر از این معمولاً توضیح/گفتگو می‌خواهند → آنلاین.
  final int maxLocalLength;

  /// تصمیم می‌گیرد برای این پرسش کدام مسیر استفاده شود.
  RouteTarget decide({
    required String text,
    required double? localConfidence,
    required bool localCanHandle,
    required int localSuccessCount,
    required int localFailureCount,
  }) {
    final t = text.trim();
    if (t.isEmpty) return RouteTarget.localOnly;

    final qType = PersianQuestionClassifier.classify(t);

    // ۱) سؤال مالی/چیستیِ باز که محلی دقیق نمی‌فهمد → آنلاین.
    if (qType == QuestionType.money && !localCanHandle) {
      return RouteTarget.online;
    }
    if (qType == QuestionType.why && !localCanHandle) {
      return RouteTarget.online;
    }

    // ۲) اگر محلی این intent را قبلاً زیاد اشتباه جواب داده، آنلاین (اولویت بالا).
    final total = localSuccessCount + localFailureCount;
    if (localCanHandle && total >= 4) {
      final failRate = localFailureCount / total;
      if (failRate > 0.5) return RouteTarget.online;
    }

    // ۳) پرسش‌های خیلی کوتاه با intent محلی قوی → محلی.
    if (localCanHandle &&
        (localConfidence ?? 0) >= confidenceThreshold &&
        t.length <= maxLocalLength) {
      return RouteTarget.localOnly;
    }

    // ۴) اگر محلی می‌تواند ولی اطمینانش متوسط است، اول محلی.
    if (localCanHandle) {
      return RouteTarget.localFirst;
    }

    // ۵) هر چیز دیگری (سؤال باز، چیستی، نامرتبط) → آنلاین.
    return RouteTarget.online;
  }
}
