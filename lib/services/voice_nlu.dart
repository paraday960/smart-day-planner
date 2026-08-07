import '../models/debt_item.dart';

/// ابزارهای NLU فارسی (نرمال‌سازی، استخراج مبلغ/نام/مهلت از متن فرمان صوتی).
///
/// از [VoiceCommandProcessor] جدا شده‌اند تا فایل آن‌قدر بزرگ نشود و
/// این توابع خالص (بدون وابستگی به state) مستقلاً قابل تست باشند.
class VoiceNlu {
  const VoiceNlu._();

  /// استخراج چند نام از «به علی و محمد و حسن بدهکارم».
  /// اگر فقط یک نام باشد (یا الگو پیدا نشود) لیست خالی برمی‌گردد.
  List<String> extractMultiDebtPersons(String text) {
    final normalized = normalize(text);
    final match = RegExp(r'به\s+(.+?)\s+بدهکارم').firstMatch(normalized);
    if (match == null) return const [];

    final rawNames = match.group(1)!;
    // جدا کردن فقط با «و»ی که بین دو فاصله است تا «و» داخل کلماتی مثل
    // «میلیون» یا «بیست و پنج» نام را اشتباهی چندتکه نکند.
    final names = rawNames
        .split(RegExp(r'\s+و\s+'))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty && n.length <= 20 && !containsAny(n, [
              'میلیون',
              'هزار',
              'تومان',
              'تومن',
              'میلیارد',
            ]))
        .toList();
    return names.length >= 2 ? names : const [];
  }

  /// پیدا کردن مبلغ اختصاصی یک شخص: «به <نام> <مبلغ>».
  int? extractAmountForPerson(String text, String person) {
    final normalized = normalize(text);
    final match = RegExp('به\\s*$person\\s*(.+?)(?=به\\s|\\،|،|\.|\$)')
        .firstMatch(normalized);
    if (match == null) return null;
    final segment = match.group(1)!;
    final amount = parseAmount(segment);
    return amount > 0 ? amount : null;
  }

  String extractPersonNameForDebt(String text, DebtType type) {
    final normalized = normalize(text);

    if (type == DebtType.debt) {
      final toMatch = RegExp(r'به\s+(\S+)').firstMatch(normalized);
      if (toMatch != null) return toMatch.group(1) ?? '';
      final debtMatch = RegExp(r'(\S+)\s+(یک|یه|دو|سه|چهار|پنج|شش|شیش|هفت|هشت|نه|ده|\d+)').firstMatch(normalized);
      if (debtMatch != null) return debtMatch.group(1) ?? '';
    } else {
      final fromMatch = RegExp(r'از\s+(\S+)').firstMatch(normalized);
      if (fromMatch != null) return fromMatch.group(1) ?? '';
    }

    return '';
  }

  String cleanPlannedExpenseTitle(String rawText) {
    var title = normalize(rawText);
    final patterns = [
      r'هفته دیگه',
      r'هفته بعد',
      r'امروز',
      r'فردا',
      r'میخام',
      r'میخوام',
      r'می‌خوام',
      r'می خوام',
      r'خرج داره',
      r'هزینه داره',
      r'یک میلیون',
      r'یه میلیون',
      r'\d+\s*(میلیون|هزار|تومان|تومن|ریال)?',
      r'و',
    ];
    for (final pattern in patterns) {
      title = title.replaceAll(RegExp(pattern), ' ');
    }
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String cleanTaskTitle(String rawText) {
    var title = normalize(rawText);
    final patterns = [
      r'کار جدید',
      r'کار جدید',
      r'وظیفه جدید',
      r'اضافه کن',
      r'ثبت کن',
      r'یادم بنداز',
      r'که',
      r'برای امروز',
      r'برای فردا',
      r'امروز',
      r'فردا',
      r'این هفته',
      r'خیلی مهم',
      r'فوری',
      r'ضروری',
      r'ساعت\s+\S+',
      r'تا\s+\S+\s+(دقیقه|ساعت)\s+(دیگه|دیگر)',
    ];
    for (final pattern in patterns) {
      title = title.replaceAll(RegExp(pattern), ' ');
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title;
  }

  DateTime? guessDueAt(String text) {
    final now = DateTime.now();

    // ── مهلت‌های «ماه» ──
    // «تا ماه آینده» / «ماه دیگه» / «ماه بعد» → آخر ماه بعد
    if (containsAny(text, ['تا ماه آینده', 'ماه آینده', 'ماه دیگه', 'ماه بعد', 'تا ماه دیگه'])) {
      final next = DateTime(now.year, now.month + 1, 1);
      return DateTime(next.year, next.month + 1, 0, 23, 59);
    }
    // «تا ۲ ماه دیگه» / «تا ۱ ماه دیگر»
    final monthsDigit = RegExp(r'تا\s+(\d+)\s*ماه\s*(دیگه|دیگر|بعد)?').firstMatch(text);
    if (monthsDigit != null) {
      final m = int.parse(monthsDigit.group(1)!);
      final target = DateTime(now.year, now.month + m, 1);
      return DateTime(target.year, target.month + 1, 0, 23, 59);
    }
    final monthsWord = RegExp(r'تا\s+(\S+)\s*ماه\s*(دیگه|دیگر|بعد)?').firstMatch(text);
    if (monthsWord != null) {
      final m = parseSmallNumber(monthsWord.group(1)!);
      if (m != null) {
        final target = DateTime(now.year, now.month + m, 1);
        return DateTime(target.year, target.month + 1, 0, 23, 59);
      }
    }

    final relativeMinutes = RegExp(r'تا\s+(\d+)\s*(دقیقه|مین)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeMinutes != null) {
      return now.add(Duration(minutes: int.parse(relativeMinutes.group(1)!)));
    }

    final relativeHours = RegExp(r'تا\s+(\d+)\s*(ساعت)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeHours != null) {
      return now.add(Duration(hours: int.parse(relativeHours.group(1)!)));
    }

    final relativeDaysDigit = RegExp(r'تا\s+(\d+)\s*(روز)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeDaysDigit != null) {
      return now.add(Duration(days: int.parse(relativeDaysDigit.group(1)!)));
    }

    final relativeDaysWord = RegExp(r'تا\s+(\S+)\s*(روز)\s*(دیگه|دیگر)?').firstMatch(text);
    if (relativeDaysWord != null) {
      final days = parseSmallNumber(relativeDaysWord.group(1)!);
      if (days != null) return now.add(Duration(days: days));
    }

    final plainDaysDigit = RegExp(r'(\d+)\s*(روز)\s*(دیگه|دیگر)').firstMatch(text);
    if (plainDaysDigit != null) {
      return now.add(Duration(days: int.parse(plainDaysDigit.group(1)!)));
    }

    final plainDaysWord = RegExp(r'(\S+)\s*(روز)\s*(دیگه|دیگر)').firstMatch(text);
    if (plainDaysWord != null) {
      final days = parseSmallNumber(plainDaysWord.group(1)!);
      if (days != null) return now.add(Duration(days: days));
    }

    var baseDate = DateTime(now.year, now.month, now.day);
    var hasDate = false;
    if (text.contains('فردا')) {
      final tomorrow = now.add(const Duration(days: 1));
      baseDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      hasDate = true;
    } else if (text.contains('امروز')) {
      hasDate = true;
    } else if (text.contains('هفته دیگه') || text.contains('هفته بعد') || text.contains('این هفته')) {
      return now.add(const Duration(days: 7));
    }

    final hour = extractHour(text);
    if (hour != null) {
      var fixedHour = hour;
      if ((text.contains('عصر') || text.contains('شب') || text.contains('بعد از ظهر')) && fixedHour < 12) {
        fixedHour += 12;
      }
      if (!hasDate && fixedHour <= now.hour) {
        baseDate = baseDate.add(const Duration(days: 1));
      }
      return DateTime(baseDate.year, baseDate.month, baseDate.day, fixedHour.clamp(0, 23).toInt());
    }

    if (hasDate) return DateTime(baseDate.year, baseDate.month, baseDate.day, 22);
    return null;
  }

  int? extractHour(String text) {
    final normalized = convertPersianDigits(text);
    final digitAfter = RegExp(r'ساعت\s+(\d{1,2})').firstMatch(normalized);
    if (digitAfter != null) return int.parse(digitAfter.group(1)!);

    final wordAfter = RegExp(r'ساعت\s+(\S+)').firstMatch(normalized);
    if (wordAfter != null) return parseSmallNumber(wordAfter.group(1)!);
    return null;
  }

  int? parseSmallNumber(String value) {
    final normalized = convertPersianDigits(value);
    final digit = int.tryParse(normalized);
    if (digit != null) return digit;
    return _numberWords[normalized];
  }

  int guessMinutes(String text, {int fallback = 30}) {
    final normalized = convertPersianDigits(text);
    final minuteMatch = RegExp(r'(\d+)\s*(دقیقه|مین|minute)').firstMatch(normalized);
    if (minuteMatch != null) return int.parse(minuteMatch.group(1)!).clamp(5, 24 * 60).toInt();

    final hourMatch = RegExp(r'(\d+)\s*(ساعت|hour)').firstMatch(normalized);
    if (hourMatch != null) return (int.parse(hourMatch.group(1)!) * 60).clamp(5, 24 * 60).toInt();

    if (text.contains('کوتاه') || text.contains('سریع')) return 15;
    if (text.contains('طولانی') || text.contains('زیاد')) return 90;
    return fallback;
  }

  int? parseAmbiguousSpokenAmount(String text) {
    final normalized = normalize(text);
    // در فارسی محاوره‌ای «پونصد» معمولاً یعنی ۵۰۰ هزار تومان؛ چون مبهم است با تأیید اجرا می‌کنیم.
    if (containsAny(normalized, ['پونصد', 'پانصد']) && !containsAny(normalized, ['هزار', 'میلیون', 'تومان', 'تومن', 'ریال'])) {
      return 500000;
    }
    if (containsAny(normalized, ['صد']) && !containsAny(normalized, ['هزار', 'میلیون', 'تومان', 'تومن', 'ریال'])) {
      return 100000;
    }
    return null;
  }

  int parseAmount(String text) {
    final normalized = normalize(text).replaceAll(',', '').replaceAll('٬', '');

    final digitMatches = RegExp(r'(\d+)\s*(میلیون|هزار|تومان|تومن|ریال)?').allMatches(normalized).toList();
    for (final match in digitMatches) {
      var amount = int.parse(match.group(1)!);
      final suffix = match.group(2) ?? '';
      if (suffix.contains('میلیون')) return amount * 1000000;
      if (suffix.contains('هزار')) return amount * 1000;
      if (suffix.contains('ریال')) return (amount / 10).round();
      if (suffix.contains('تومان') || suffix.contains('تومن') || amount >= 1000) return amount;
    }

    final words = normalized.split(RegExp(r'\s+'));
    var total = 0;
    var current = 0;
    var sawMoneyScale = false;

    for (final rawWord in words) {
      final word = rawWord.trim();
      if (word == 'و') continue;

      final value = _numberWords[word];
      if (value != null) {
        current += value;
        continue;
      }

      if (word.contains('میلیون')) {
        total += (current == 0 ? 1 : current) * 1000000;
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      if (word.contains('هزار')) {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      if (word.contains('ریال')) {
        total += (current / 10).round();
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      if (word.contains('تومان') || word.contains('تومن')) {
        total += current;
        current = 0;
        sawMoneyScale = true;
        continue;
      }

      // اگر کلمه غیرعددی آمد، احتمالاً عدد قبلی مربوط به ساعت/زمان بوده نه پول.
      current = 0;
    }

    if (sawMoneyScale) return total + current;
    return 0;
  }

  int wordOverlap(String a, String b) {
    final aw = a.split(' ').where((w) => w.length > 2).toSet();
    final bw = b.split(' ').where((w) => w.length > 2).toSet();
    return aw.intersection(bw).length;
  }

  bool looksLikeWork(String text) {
    return containsAny(text, [
      'کار',
      'درآمد',
      'پروژه',
      'مشتری',
      'فروش',
      'فریلنس',
      'تدریس',
      'شیفت',
      'قرارداد',
      'سفارش',
    ]);
  }

  bool containsAny(String text, List<String> words) => words.any(text.contains);

  String normalize(String value) {
    return convertPersianDigits(value)
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'[،,.!؟?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String convertPersianDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
    }
    return result;
  }

  static const Map<String, int> _numberWords = {
    'صفر': 0,
    'یک': 1,
    'یه': 1,
    'دو': 2,
    'سه': 3,
    'چهار': 4,
    'پنج': 5,
    'شش': 6,
    'شیش': 6,
    'هفت': 7,
    'هشت': 8,
    'نه': 9,
    'ده': 10,
    'یازده': 11,
    'دوازده': 12,
    'سیزده': 13,
    'چهارده': 14,
    'پانزده': 15,
    'شانزده': 16,
    'هفده': 17,
    'هجده': 18,
    'نوزده': 19,
    'بیست': 20,
    'سی': 30,
    'چهل': 40,
    'پنجاه': 50,
    'شصت': 60,
    'هفتاد': 70,
    'هشتاد': 80,
    'نود': 90,
    'صد': 100,
    'یکصد': 100,
    'دویست': 200,
    'سیصد': 300,
    'چهارصد': 400,
    'پانصد': 500,
    'ششصد': 600,
    'هفتصد': 700,
    'هشتصد': 800,
    'نهصد': 900,
  };
}
