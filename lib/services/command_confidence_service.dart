class CommandConfidenceResult {
  const CommandConfidenceResult({
    required this.intent,
    required this.score,
    required this.reasons,
  });

  final String intent;
  final double score;
  final List<String> reasons;

  bool get isLowConfidence => score < 0.75;
}

class CommandConfidenceService {
  const CommandConfidenceService();

  CommandConfidenceResult evaluate({
    required String text,
    required String intent,
    required int amount,
    String? personName,
    DateTime? dueAt,
  }) {
    var score = 0.35;
    final reasons = <String>[];

    if (amount > 0) {
      score += 0.22;
    } else {
      reasons.add('مبلغ نامشخص است');
    }

    if (text.contains('تومان') || text.contains('تومن') || text.contains('هزار') || text.contains('میلیون')) {
      score += 0.13;
    } else if (_hasAmbiguousMoneyWord(text)) {
      score -= 0.15;
      reasons.add('مبلغ محاوره‌ای و مبهم است');
    }

    if (personName != null && personName.trim().isNotEmpty && personName != 'نامشخص') {
      score += 0.12;
    }

    if (dueAt != null) score += 0.10;

    if (_hasIntentKeyword(text, intent)) {
      score += 0.18;
    } else {
      reasons.add('نوع عملیات کاملاً روشن نیست');
    }

    if (amount >= 5000000) {
      score -= 0.08;
      reasons.add('مبلغ بزرگ است');
    }

    return CommandConfidenceResult(
      intent: intent,
      score: score.clamp(0, 1).toDouble(),
      reasons: reasons,
    );
  }

  bool shouldConfirm(CommandConfidenceResult result, {required int amount}) {
    return result.isLowConfidence || amount >= 1000000;
  }

  bool _hasAmbiguousMoneyWord(String text) {
    return text.contains('پونصد') || text.contains('پانصد') || text.contains('صد') || text.contains('یه تومن');
  }

  bool _hasIntentKeyword(String text, String intent) {
    switch (intent) {
      case 'debt':
        return text.contains('بدهکار') || text.contains('بدهی');
      case 'expense':
        return text.contains('هزینه') || text.contains('خرج') || text.contains('پرداخت');
      case 'plannedExpense':
        return text.contains('خرج داره') || text.contains('هزینه داره') || text.contains('برنامه هزینه');
      case 'allocation':
        return text.contains('کنار') || text.contains('اختصاص');
      case 'payment':
        return text.contains('پرداخت') || text.contains('پس دادم') || text.contains('تسویه');
      default:
        return true;
    }
  }
}
