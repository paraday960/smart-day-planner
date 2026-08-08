/// ابزارهای سبک پردازش زبان فارسی (NLU) برای دستیار هوشمند.
///
/// ارتقای هوش محلی (۲۰۲۶-۰۸-۰۸):
/// - توکنایزر فارسی، تطبیق در سطح کلمه، IntentMatch با confidence
/// - تشخیص نوع سؤال و اشاره‌فهمی (آنافورا)
/// - شباهت معنایی سبک (Jaccard + هم‌معناها + بایگرام)
library;

class PersianNormalizer {
  const PersianNormalizer._();

  static const Map<String, String> _charMap = {
    '\u0643': '\u06a9', '\u0649': '\u06cc', '\u064a': '\u06cc',
    '\u0626': '\u06cc', '\u0629': '\u0647', '\u0623': '\u0627',
    '\u0625': '\u0627', '\u0622': '\u0627', '\u0624': '\u0648',
  };

  static final RegExp _diacritics = RegExp(
    '[\u064b-\u0652\u0640\u0670\u064e\u064f\u0650\u0651\u0652\u0653\u0670]',
  );

  static String normalize(String input, {bool keepZwnj = true}) {
    if (input.isEmpty) return input;
    var text = input;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_charMap[ch] ?? ch);
    }
    text = buffer.toString();
    text = text
        .replaceAll('۰', '0').replaceAll('۱', '1').replaceAll('۲', '2')
        .replaceAll('۳', '3').replaceAll('۴', '4').replaceAll('۵', '5')
        .replaceAll('۶', '6').replaceAll('۷', '7').replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2')
        .replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5')
        .replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8')
        .replaceAll('٩', '9');
    text = text.replaceAll(_diacritics, '');
    text = text.replaceAll('\u200b', '').replaceAll('\u200e', '');
    if (!keepZwnj) text = text.replaceAll('\u200c', '');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String loose(String input) =>
      normalize(input, keepZwnj: false).replaceAll(' ', '');

  static List<String> tokenize(String input) {
    final text = normalize(input, keepZwnj: false).toLowerCase();
    return text
        .split(RegExp(r'[\s\u200c]+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
  }
}

class PersianMatcher {
  const PersianMatcher._();

  static bool hasAny(String text, Iterable<String> patterns) {
    final strict = PersianNormalizer.normalize(text, keepZwnj: true);
    final noZwnj = PersianNormalizer.normalize(text, keepZwnj: false);
    for (final pattern in patterns) {
      final pStrict = PersianNormalizer.normalize(pattern, keepZwnj: true);
      final pNoZwnj = PersianNormalizer.normalize(pattern, keepZwnj: false);
      if (strict.contains(pStrict)) return true;
      if (noZwnj.contains(pNoZwnj)) return true;
      if (PersianNormalizer.loose(text)
          .contains(PersianNormalizer.loose(pattern))) {
        return true;
      }
    }
    return false;
  }

  static int countMatches(String text, Iterable<String> patterns) {
    var count = 0;
    for (final pattern in patterns) {
      if (hasAny(text, [pattern])) count++;
    }
    return count;
  }

  static bool hasWord(String text, String word) {
    final tokens = PersianNormalizer.tokenize(text).toSet();
    return tokens.contains(
        PersianNormalizer.normalize(word, keepZwnj: false).toLowerCase().trim());
  }

  static int countWords(String text, Iterable<String> words) {
    final tokens = PersianNormalizer.tokenize(text).toSet();
    var count = 0;
    for (final w in words) {
      if (tokens.contains(PersianNormalizer.normalize(w, keepZwnj: false)
          .toLowerCase())) {
        count++;
      }
    }
    return count;
  }
}

class NluIntent {
  const NluIntent({
    required this.id,
    required this.patterns,
    this.priority = 0,
    this.keywords = const [],
    this.requiresKeywords = const [],
  });
  final String id;
  final List<String> patterns;
  final int priority;
  final List<String> keywords;
  final List<String> requiresKeywords;
}

class IntentMatch {
  const IntentMatch({
    required this.intent,
    required this.score,
    required this.confidence,
  });
  final NluIntent intent;
  final double score;
  final double confidence;
  String get id => intent.id;
}

class IntentDetector {
  const IntentDetector({this.intents = const []});
  final List<NluIntent> intents;

  NluIntent? detect(String text) => detectWithScore(text)?.intent;

  double _scoreFor(NluIntent intent, String normalized) {
    final matchCount =
        PersianMatcher.countMatches(normalized, intent.patterns);
    final keywordCount =
        PersianMatcher.countWords(normalized, intent.keywords);
    if (matchCount == 0 && keywordCount == 0) return 0;
    var maxLen = 0;
    for (final pattern in intent.patterns) {
      if (PersianMatcher.hasAny(normalized, [pattern]) &&
          pattern.length > maxLen) {
        maxLen = pattern.length;
      }
    }
    var score =
        matchCount * 100 + keywordCount * 25 + maxLen + intent.priority;
    for (final blocker in intent.requiresKeywords) {
      if (PersianMatcher.hasWord(normalized, blocker)) score -= 40;
    }
    return score.toDouble();
  }

  IntentMatch? detectWithScore(String text) {
    final normalized = PersianNormalizer.normalize(text);
    if (normalized.isEmpty) return null;
    IntentMatch? best;
    for (final intent in intents) {
      final score = _scoreFor(intent, normalized);
      if (score <= 0) continue;
      if (best == null || score > best.score) {
        best = IntentMatch(intent: intent, score: score, confidence: 0);
      }
    }
    if (best == null) return null;
    final raw = best.score;
    final confidence = raw >= 200
        ? 0.95
        : raw >= 100
            ? 0.8
            : raw >= 50
                ? 0.55
                : 0.35;
    return IntentMatch(
      intent: best.intent,
      score: raw,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  List<IntentMatch> detectCandidates(String text, {int top = 3}) {
    final normalized = PersianNormalizer.normalize(text);
    if (normalized.isEmpty) return const [];
    final matches = <IntentMatch>[];
    for (final intent in intents) {
      final score = _scoreFor(intent, normalized);
      if (score > 0) {
        matches.add(IntentMatch(intent: intent, score: score, confidence: 0));
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(top).toList();
  }
}

enum QuestionType { planning, money, time, what, why, greeting, unknown }

class PersianQuestionClassifier {
  const PersianQuestionClassifier._();
  static const Set<String> _timeWords = {
    'کی', 'امروز', 'فردا', 'دیروز', 'هفته', 'ماه', 'الان',
    'ساعت', 'تاریخ', 'شنبه', 'یکشنبه', 'دوشنبه', 'سهشنبه',
    'چهارشنبه', 'پنجشنبه', 'جمعه', 'بعد', 'بعدا',
  };
  static const Set<String> _moneyWords = {
    'پول', 'مالی', 'هزینه', 'درآمد', 'بدهی', 'بدهکار', 'طلب',
    'تومان', 'هزار', 'میلیون', 'خرج', 'قرض', 'وام', 'بودجه',
    'مانده', 'حساب', 'پسانداز', 'پس‌انداز',
  };
  static const Set<String> _planningWords = {
    'برنامه', 'کار', 'وظیفه', 'تسک', 'انجام', 'شروع', 'تمام',
    'عقب', 'ریسک', 'مهلت', 'استراحت', 'تمرکز', 'جبران',
  };

  static QuestionType classify(String text) {
    final tokens = PersianNormalizer.tokenize(text).toSet();
    if (tokens.isEmpty) return QuestionType.unknown;
    bool hasAny(Set<String> w) => w.any(tokens.contains);
    if (hasAny(_moneyWords)) return QuestionType.money;
    if (hasAny(_timeWords)) return QuestionType.time;
    if (hasAny(_planningWords)) return QuestionType.planning;
    if (tokens.contains('چرا')) return QuestionType.why;
    if (tokens.contains('چیه') ||
        tokens.contains('چیست') ||
        tokens.contains('چی')) {
      return QuestionType.what;
    }
    if (tokens.contains('سلام') ||
        tokens.contains('درود') ||
        tokens.contains('خوبی')) {
      return QuestionType.greeting;
    }
    return QuestionType.unknown;
  }
}

class AnaphoraDetector {
  const AnaphoraDetector._();
  static const List<String> _phrases = [
    'ادامه', 'ادامهش', 'بعدش', 'بعدیش', 'بقیه', 'بقیهش',
    'دومیش', 'سومیش', 'آخرش', 'اون', 'اونو', 'اونم',
    'خودش', 'ازش', 'براش', 'همون', 'همین',
  ];
  static bool isFollowUp(String text) {
    final loose = PersianNormalizer.loose(text);
    for (final p in _phrases) {
      if (loose.contains(p)) return true;
    }
    final tokens = PersianNormalizer.tokenize(text);
    if (tokens.length <= 3 &&
        (tokens.contains('چی') || tokens.contains('چقدر')) &&
        !tokens.any((t) => RegExp(r'^\d').hasMatch(t))) {
      return true;
    }
    return false;
  }
}

class PersianSemanticSimilarity {
  const PersianSemanticSimilarity._();
  static const Set<String> _stopwords = {
    'برای', 'چه', 'چطور', 'چگونه', 'چرا', 'چیست', 'چیه', 'چقدره', 'چقدر',
    'چند', 'که', 'به', 'از', 'در', 'با', 'من', 'تو', 'ما', 'شما', 'می',
    'رو', 'یه', 'یک', 'این', 'آن', 'بود', 'هست', 'هستم', 'دارم', 'میخوام',
    'میشه', 'کردن', 'کرد', 'کنم', 'کنی', 'بده', 'بگو', 'سلام', 'لطفا',
    'آیا', 'یا', 'نه', 'بله', 'آره', 'خب', 'و', 'را', 'هم', 'نیست',
    'ندارم', 'باید', 'میتونم', 'میتونی', 'الان', 'حالا', 'کردم', 'کردی',
    'کند', 'شود', 'باشه', 'درباره', 'برام', 'برات', 'خواستم',
  };
  static const Map<String, String> _synonyms = {
    'قرض': 'بدهی', 'وام': 'بدهی', 'بدهکاری': 'بدهی',
    'بدهکارم': 'بدهی', 'بدهکار': 'بدهی', 'طلب': 'بدهی',
    'طلبکار': 'بدهی', 'مانده': 'بدهی',
    'خرج': 'هزینه', 'مخارج': 'هزینه',
    'درامد': 'درآمد', 'حقوق': 'درآمد',
    'کارها': 'کار', 'تسک': 'کار', 'وظیفه': 'کار',
    'برنامهه': 'برنامه',
    'چقدره': 'چقدر', 'چنده': 'چقدر',
  };

  static String _canonical(String w) {
    var word = w;
    for (final suffix in ['\u200cام', '\u200cات', '\u200cاش', 'مون', 'تون', 'شون']) {
      if (word.endsWith(suffix) && word.length > suffix.length + 2) {
        word = word.substring(0, word.length - suffix.length);
        break;
      }
    }
    return _synonyms[word] ?? word;
  }

  static Set<String> _content(String text) => PersianNormalizer.tokenize(text)
      .where((w) => w.length >= 2 && !_stopwords.contains(w))
      .map(_canonical)
      .toSet();

  static double score(String a, String b) {
    final sa = _content(a);
    final sb = _content(b);
    if (sa.isEmpty && sb.isEmpty) return a == b ? 1.0 : 0.0;
    if (sa.isEmpty || sb.isEmpty) return 0.0;
    final inter = sa.intersection(sb);
    final union = sa.union(sb);
    final jac = inter.isEmpty ? 0.0 : inter.length / union.length;
    final cont =
        sa.containsAll(sb) || sb.containsAll(sa) ? 0.15 : 0.0;
    final big = _bigram(a, b);
    return (jac * 0.65 + big * 0.2 + cont).clamp(0.0, 1.0);
  }

  static double _bigram(String a, String b) {
    Set<String> bg(String s) {
      final s2 = PersianNormalizer.loose(s);
      if (s2.length < 2) return {s2};
      final set = <String>{};
      for (var i = 0; i < s2.length - 1; i++) {
        set.add(s2.substring(i, i + 2));
      }
      return set;
    }
    final sa = bg(a);
    final sb = bg(b);
    if (sa.isEmpty || sb.isEmpty) return 0.0;
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    return union == 0 ? 0.0 : inter / union;
  }
}
