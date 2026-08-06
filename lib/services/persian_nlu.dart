/// ابزارهای سبک پردازش زبان فارسی (NLU) برای دستیار هوشمند.
///
/// این کلاس‌ها هیچ وابستگی خارجی ندارند و کاملاً unit-test پذیر هستند.
/// هدف: نرمال‌سازی متن فارسی (یکسان‌سازی حروف عربی/فارسی، اعداد، فاصله‌ها)
/// و تطبیق الگوهای پرسش با الگوهای هر «قصد» (intent).
library;

/// نرمال‌سازی متن فارسی/عربی برای مقایسهٔ مطمئن.
class PersianNormalizer {
  const PersianNormalizer._();

  /// نگاشت حروف عربی به معادل فارسی.
  static const Map<String, String> _charMap = {
    // کاف عربی -> کاف فارسی
    '\u0643': '\u06a9', // ك -> ک
    // ی عربی (بدون نقطه)، ی عربی و ی همزه‌دار -> ی فارسی
    '\u0649': '\u06cc', // ى -> ی
    '\u064a': '\u06cc', // ي -> ی
    '\u0626': '\u06cc', // ئ -> ی
    // ه تاء مربوطه -> ه
    '\u0629': '\u0647', // ة -> ه
    // الف‌های همزه‌دار -> الف ساده
    '\u0623': '\u0627', // أ -> ا
    '\u0625': '\u0627', // إ -> ا
    '\u0622':
        '\u0627', // آ -> ا (در نسخهٔ ساده؛ «آ» در کلماتی مثل «آب» با «اب» یکی می‌شود)
    // واو همزه‌دار -> واو
    '\u0624': '\u0648', // ؤ -> و
  };

  /// حذف اعراب و کشیده و فاصله‌های اضافی.
  static final RegExp _diacritics = RegExp(
    '[\u064b-\u0652\u0640\u0670\u064e\u064f\u0650\u0651\u0652\u0653\u0670]',
  );

  /// نرمال‌سازی کامل: حروف، اعداد، اعراب، فاصله‌ها.
  ///
  /// اگر [keepZwnj] true باشد، نیم‌فاصله (ZWNJ) حفظ می‌شود؛
  /// در غیر این صورت حذف می‌شود (برای تطبیق الگوها).
  static String normalize(String input, {bool keepZwnj = true}) {
    if (input.isEmpty) return input;
    var text = input;

    // حروف عربی -> فارسی
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_charMap[ch] ?? ch);
    }
    text = buffer.toString();

    // اعداد فارسی/عربی -> لاتین
    text = text
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    // حذف اعراب و کشیدگی
    text = text.replaceAll(_diacritics, '');

    // یکسان‌سازی فاصله‌های خاص (فاصلهٔ نامرئی، فاصلهٔ مجازی)
    text = text.replaceAll('\u200b', '').replaceAll('\u200e', '');

    // ZWNJ
    if (!keepZwnj) {
      text = text.replaceAll('\u200c', '');
    }

    // فاصله‌های تکراری -> یکی
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// نسخهٔ «سست» برای تطبیق: بدون نیم‌فاصله و بدون فاصله.
  /// برای پیدا کردن کلمات تکی داخل جمله (مثل «ریسک») به‌کار می‌رود.
  static String loose(String input) =>
      normalize(input, keepZwnj: false).replaceAll(' ', '');
}

/// تطبیق الگوهای متنی با نرمال‌سازی فارسی.
class PersianMatcher {
  const PersianMatcher._();

  /// آیا متن (نرمال‌شده) حداقل یکی از الگوها را دارد؟
  static bool hasAny(String text, Iterable<String> patterns) {
    final strict = PersianNormalizer.normalize(text, keepZwnj: true);
    final noZwnj = PersianNormalizer.normalize(text, keepZwnj: false);
    for (final pattern in patterns) {
      final pStrict = PersianNormalizer.normalize(pattern, keepZwnj: true);
      final pNoZwnj = PersianNormalizer.normalize(pattern, keepZwnj: false);
      if (strict.contains(pStrict)) return true;
      if (noZwnj.contains(pNoZwnj)) return true;
      // کلمه‌های جدا (مثل «انجام بده») را با نسخهٔ سست هم چک کن
      if (PersianNormalizer.loose(text)
          .contains(PersianNormalizer.loose(pattern))) {
        return true;
      }
    }
    return false;
  }

  /// چند الگو از [patterns] در متن آمده است؟ (برای امتیازدهی)
  static int countMatches(String text, Iterable<String> patterns) {
    var count = 0;
    for (final pattern in patterns) {
      if (hasAny(text, [pattern])) count++;
    }
    return count;
  }
}

/// یک «قصد» (intent) قابل تشخیص توسط دستیار.
class NluIntent {
  const NluIntent(
      {required this.id, required this.patterns, this.priority = 0});

  final String id;
  final List<String> patterns;

  /// هرچه بزرگ‌تر باشد، در تساوی امتیاز اولویت بیشتری دارد.
  final int priority;
}

/// تشخیص قصد از روی متن کاربر با امتیازدهی الگوها.
class IntentDetector {
  const IntentDetector({this.intents = const []});

  final List<NluIntent> intents;

  /// بهترین قصد تطبیق‌یافته را برمی‌گرداند؛ اگر هیچ الگویی نیامد null.
  NluIntent? detect(String text) {
    if (text.isEmpty) return null;
    NluIntent? best;
    var bestScore = 0;

    for (final intent in intents) {
      final matches = PersianMatcher.countMatches(text, intent.patterns);
      if (matches == 0) continue;

      // امتیاز = تعداد تطبیق + طول بلندترین الگوی تطبیق‌یافته (برای اختصاصی بودن) + اولویت
      var maxLen = 0;
      for (final pattern in intent.patterns) {
        if (PersianMatcher.hasAny(text, [pattern]) && pattern.length > maxLen) {
          maxLen = pattern.length;
        }
      }
      final score = matches * 100 + maxLen + intent.priority;

      if (score > bestScore) {
        bestScore = score;
        best = intent;
      }
    }

    return best;
  }
}
