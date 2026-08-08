import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// منبع یادگیری یک ورودی حافظه.
///
/// - [online] : از پاسخ هوش آنلاین یاد گرفته شده (هستهٔ این ماژول)
/// - [local]  : از موتور محلی/سناریو ذخیره شده
/// - [correction] : با تصحیح کاربر اصلاح شده (دقیق‌ترین منبع)
/// - [import] : از نسخهٔ قدیمی یا فایل خارجی وارد شده
enum MemorySource { online, local, correction, import }

/// یک ورودی ساختاریافتهٔ حافظهٔ یادگیری محلی.
///
/// برخلاف نسخهٔ قبلی (نقشهٔ سادهٔ «سؤال → جواب») هر ورودی متادیتا دارد:
/// از کجا یاد گرفته شده، چه زمانی، چند بار استفاده شده و امتیاز بازخورد کاربر.
class MemoryEntry {
  MemoryEntry({
    required this.question,
    required this.answer,
    this.source = MemorySource.local,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    this.useCount = 0,
    this.feedbackScore = 0.0,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUsedAt = lastUsedAt ?? DateTime.now();

  /// سؤال نرمال‌شده (کلید حافظه).
  final String question;

  /// پاسخ یادگرفته‌شده.
  String answer;

  /// منبع یادگیری.
  MemorySource source;

  /// زمان یادگیری.
  DateTime createdAt;

  /// آخرین باری که این دانش استفاده شده.
  DateTime lastUsedAt;

  /// تعداد دفعاتی که این یادگیری به کار رفته (تقویت).
  int useCount;

  /// امتیاز بازخورد کاربر در بازهٔ -1 (بازخورد منفی مکرر) تا +1 (بازخورد مثبت مکرر).
  double feedbackScore;

  /// کیفیت برآوردی ورودی (۰ تا ۱) — از روی بازخورد کاربر.
  double get quality => ((feedbackScore + 1) / 2).clamp(0.0, 1.0);

  /// آیا به‌قدری بی‌اعتبار شده که نباید مستقیم استفاده شود؟
  bool get degraded => feedbackScore <= -0.5;

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'source': source.name,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
        'useCount': useCount,
        'feedbackScore': feedbackScore,
      };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
        question: (json['question'] ?? '').toString(),
        answer: (json['answer'] ?? '').toString(),
        source: MemorySource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => MemorySource.local,
        ),
        createdAt:
            DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        lastUsedAt:
            DateTime.tryParse((json['lastUsedAt'] ?? '').toString()) ??
            DateTime.now(),
        useCount: (json['useCount'] as num?)?.toInt() ?? 0,
        feedbackScore: (json['feedbackScore'] as num?)?.toDouble() ?? 0.0,
      );

  MemoryEntry copyWith({String? answer, MemorySource? source, double? feedbackScore}) =>
      MemoryEntry(
        question: question,
        answer: answer ?? this.answer,
        source: source ?? this.source,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt,
        useCount: useCount,
        feedbackScore: feedbackScore ?? this.feedbackScore,
      );
}

/// آمار کلی حافظه برای داشبورد یادگیری.
class MemoryStats {
  MemoryStats({
    required this.total,
    required this.bySource,
    required this.totalHits,
    required this.avgFeedback,
    required this.topTopics,
    required this.degradedCount,
  });

  final int total;
  final Map<MemorySource, int> bySource;
  final int totalHits;

  /// میانگین امتیاز بازخورد (‎-1 تا +1).
  final double avgFeedback;

  /// موضوعات پرتکرار (از روی سؤال‌ها).
  final List<MapEntry<String, int>> topTopics;
  final int degradedCount;
}

/// حافظهٔ یادگیری محلی دستیار — نسخهٔ ۲ (ساختاریافته).
///
/// وقتی دستیار از هوش آنلاین یک پاسخ می‌گیرد، «سؤال → جواب + متادیتا» را
/// روی دستگاه ذخیره می‌کند. دفعهٔ بعد که کاربر همان/سؤال مشابهی بپرسد،
/// مستقیم از محلی جواب می‌دهد (سریع‌تر، رایگان و بدون نیاز به آنلاین).
///
/// تغییرات نسخهٔ ۲ نسبت به نسخهٔ ۱:
/// - هر ورودی منبع، زمان، تعداد استفاده و امتیاز بازخورد دارد
/// - یادگیری تقویتی: 👍/👎 کاربر امتیاز ورودی را تغییر می‌دهد
/// - ورودی‌های بی‌اعتبار (بازخورد منفی مکرر) از پاسخ‌گویی حذف می‌شوند
/// - حذف قدیمی‌ها بر اساس «ارزش» (تعداد استفاده + تازگی)، نه ترتیب ورود
/// - مهاجرت خودکار از نسخهٔ ۱
class LocalAssistantMemory {
  /// برای تست، می‌توان نمونهٔ جداگانه با ظرفیت کوچک ساخت.
  LocalAssistantMemory({int maxEntries = 200, String? storageKey})
      : _maxEntries = maxEntries,
        _prefKey = storageKey ?? _prefKeyV2;

  LocalAssistantMemory._() : _prefKey = _prefKeyV2, _maxEntries = 200;

  static final LocalAssistantMemory instance = LocalAssistantMemory._();

  /// کلید نسخهٔ ۱ (نقشهٔ ساده) — برای مهاجرت.
  static const _prefKeyV1 = 'local_assistant_memory';

  /// کلید نسخهٔ ۲ (ساختاریافته).
  static const _prefKeyV2 = 'local_assistant_memory_v2';

  final String _prefKey;
  final int _maxEntries;

  /// نگاشت «سؤال نرمال‌شده → ورودی».
  final Map<String, MemoryEntry> _entries = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        _parseV2(raw);
      } else {
        // مهاجرت از نسخهٔ ۱ (نقشهٔ سادهٔ سؤال→جواب)
        final oldRaw = prefs.getString(_prefKeyV1);
        if (oldRaw != null && oldRaw.isNotEmpty) {
          final decoded = jsonDecode(oldRaw);
          if (decoded is Map<String, dynamic>) {
            final now = DateTime.now();
            for (final e in decoded.entries) {
              final q = _normalize(e.key);
              if (q.isEmpty) continue;
              _entries[q] = MemoryEntry(
                question: q,
                answer: e.value.toString(),
                source: MemorySource.import,
                createdAt: now,
              );
            }
            await _save();
          }
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  void _parseV2(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final version = decoded['version'];
      final entries = decoded['entries'];
      if (version == 2 && entries is Map<String, dynamic>) {
        _entries.clear();
        for (final e in entries.entries) {
          final v = e.value;
          if (v is Map<String, dynamic>) {
            final entry = MemoryEntry.fromJson(
              Map<String, dynamic>.from(v),
            );
            if (entry.question.isNotEmpty && entry.answer.trim().isNotEmpty) {
              _entries[_normalize(entry.question)] = entry;
            }
          }
        }
      } else if (entries == null) {
        // فایل قدیمی‌تر: خودِ نقشه 'سؤال → جواب'
        final now = DateTime.now();
        for (final e in decoded.entries) {
          final q = _normalize(e.key);
          if (q.isEmpty) continue;
          _entries[q] = MemoryEntry(
            question: q,
            answer: e.value.toString(),
            source: MemorySource.import,
            createdAt: now,
          );
        }
      }
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode({
          'version': 2,
          'entries': _entries.map((k, v) => MapEntry(k, v.toJson())),
        }),
      );
    } catch (_) {}
  }

  // ─────────────────────────── خواندن ───────────────────────────

  /// آیا این سؤال از قبل در حافظه است؟ (تطبیق دقیق یا فازی)
  /// خروجی فقط جواب است — برای سازگاری با نسخهٔ قبل.
  String? lookup(String question) => lookupEntry(question)?.answer;

  /// جستجوی کامل با متادیتا.
  ///
  /// ترتیب: ۱) تطبیق دقیق  ۲) تطبیق فازی معنایی با رتبه‌بندی
  /// (ورودی‌های بی‌اعتبار [MemoryEntry.degraded] در پاسخ‌گویی شرکت نمی‌کنند).
  MemoryEntry? lookupEntry(String question) {
    final norm = _normalize(question);
    if (norm.isEmpty) return null;

    // ۱) تطبیق دقیق
    final exact = _entries[norm];
    if (exact != null && !exact.degraded) return exact;

    // ۲) تطبیق فازی معنایی — Jaccard + TF-IDF + هم‌معناها + شخص
    MemoryEntry? bestMatch;
    var bestScore = 0.0;
    for (final entry in _entries.entries) {
      if (entry.value.degraded) continue;
      final score = _rankedSimilarity(norm, entry.value);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry.value;
      }
    }
    if (bestScore >= 0.68) return bestMatch;
    return null;
  }

  /// ورودی‌های مشابه معنایی (برای تزریق دانش به پرامپت آنلاین).
  ///
  /// آستانهٔ پایین‌تری از [lookupEntry] دارد تا «دانش مرتبط» پیدا کند،
  /// حتی وقتی برای پاسخ مستقیم به‌اندازهٔ کافی نزدیک نیست.
  List<MemoryEntry> similarEntries(String question, {int limit = 3}) {
    final norm = _normalize(question);
    if (norm.isEmpty) return const [];
    final scored = <(MemoryEntry, double)>[];
    for (final entry in _entries.entries) {
      if (entry.value.degraded) continue;
      final base = _similarity(norm, entry.key);
      if (base >= 0.45 && base < 1.0) {
        scored.add((entry.value, _rankedSimilarity(norm, entry.value)));
      }
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  // ─────────────────────────── نوشتن ───────────────────────────

  /// ذخیرهٔ «سؤال → جواب» (سازگار با نسخهٔ قبل؛ منبع پیش‌فرض محلی).
  Future<void> remember(String question, String answer) =>
      rememberEntry(question, answer);

  /// ذخیرهٔ ساختاریافته با متادیتا.
  Future<void> rememberEntry(
    String question,
    String answer, {
    MemorySource source = MemorySource.local,
    double feedbackScore = 0.0,
  }) async {
    final norm = _normalize(question);
    if (norm.isEmpty || answer.trim().isEmpty) return;
    final existing = _entries[norm];
    _entries[norm] = MemoryEntry(
      question: norm,
      answer: answer.trim(),
      source: source,
      createdAt: existing?.createdAt ?? DateTime.now(),
      lastUsedAt: existing?.lastUsedAt ?? DateTime.now(),
      useCount: existing?.useCount ?? 0,
      feedbackScore: existing != null
          ? (existing.feedbackScore + feedbackScore) / 2
          : feedbackScore,
    );
    _evictIfNeeded();
    await _save();
  }

  /// به‌روزرسانی جواب یک ورودی (مثلاً تصحیح یا خوددرمانی).
  ///
  /// اگر [source] یا [feedbackScore] داده شود، همان‌ها جایگزین می‌شوند.
  Future<void> updateEntryByKey(
    String normalizedQuestion,
    String newAnswer, {
    MemorySource? source,
    double? feedbackScore,
  }) async {
    final existing = _entries[normalizedQuestion];
    if (existing == null) return;
    _entries[normalizedQuestion] = MemoryEntry(
      question: existing.question,
      answer: newAnswer.trim(),
      source: source ?? existing.source,
      createdAt: existing.createdAt,
      lastUsedAt: DateTime.now(),
      useCount: existing.useCount + 1,
      feedbackScore: feedbackScore ?? existing.feedbackScore,
    );
    await _save();
  }

  /// به‌روزرسانی جواب با متن اصلی سؤال (نرمال‌سازی داخل انجام می‌شود).
  Future<void> updateAnswer(
    String question,
    String newAnswer, {
    MemorySource? source,
    double? feedbackScore,
  }) =>
      updateEntryByKey(
        _normalize(question),
        newAnswer,
        source: source,
        feedbackScore: feedbackScore,
      );

  /// ثبت یک بار استفاده از دانش (تقویت).
  Future<void> recordHit(String question) async {
    final norm = _normalize(question);
    final entry = _entries[norm];
    if (entry == null) return;
    _entries[norm] = MemoryEntry(
      question: entry.question,
      answer: entry.answer,
      source: entry.source,
      createdAt: entry.createdAt,
      lastUsedAt: DateTime.now(),
      useCount: entry.useCount + 1,
      feedbackScore: entry.feedbackScore,
    );
    await _save();
  }

  /// ثبت بازخورد کاربر روی یک ورودی (یادگیری تقویتی).
  ///
  /// مثبت: امتیاز +۰.۳  |  منفی: امتیاز -۰.۴
  /// اگر امتیاز به -۰.۸ برسد، ورودی حذف می‌شود (خودپاک‌سازی).
  /// اگر ورودی حذف شود، null برمی‌گرداند.
  Future<MemoryEntry?> rate(
    String question, {
    required bool positive,
  }) async {
    final norm = _normalize(question);
    final entry = _entries[norm];
    if (entry == null) return null;

    var score = entry.feedbackScore + (positive ? 0.3 : -0.4);
    score = score.clamp(-1.0, 1.0);

    if (score <= -0.8) {
      _entries.remove(norm);
      await _save();
      return null;
    }

    _entries[norm] = MemoryEntry(
      question: entry.question,
      answer: entry.answer,
      source: entry.source,
      createdAt: entry.createdAt,
      lastUsedAt: DateTime.now(),
      useCount: entry.useCount + 1,
      feedbackScore: score,
    );
    await _save();
    return _entries[norm];
  }

  /// ویرایش کامل (برای صفحهٔ داشبورد).
  Future<void> updateEntry(
    String oldQuestion,
    String newQuestion,
    String newAnswer,
  ) async {
    final oldNorm = _normalize(oldQuestion);
    final existing = _entries[oldNorm];
    if (existing == null) return;
    final newNorm = _normalize(newQuestion);
    if (newNorm != oldNorm) _entries.remove(oldNorm);
    if (newNorm.isNotEmpty && newAnswer.trim().isNotEmpty) {
      _entries[newNorm] = MemoryEntry(
        question: newNorm,
        answer: newAnswer.trim(),
        source: existing.source,
        createdAt: existing.createdAt,
        lastUsedAt: DateTime.now(),
        useCount: existing.useCount,
        feedbackScore: existing.feedbackScore,
      );
    }
    _evictIfNeeded();
    await _save();
  }

  Future<void> deleteEntry(String question) async {
    final norm = _normalize(question);
    _entries.remove(norm);
    await _save();
  }

  // ─────────────────────────── آمار ───────────────────────────

  int get count => _entries.length;

  Map<String, String> get allEntries =>
      Map.unmodifiable(_entries.map((k, v) => MapEntry(k, v.answer)));

  List<MemoryEntry> get entries => List.unmodifiable(_entries.values);

  /// آمار کلی برای داشبورد یادگیری.
  MemoryStats get stats {
    final bySource = <MemorySource, int>{};
    var totalHits = 0;
    var feedbackSum = 0.0;
    var degraded = 0;
    final topicCount = <String, int>{};
    for (final e in _entries.values) {
      bySource[e.source] = (bySource[e.source] ?? 0) + 1;
      totalHits += e.useCount;
      feedbackSum += e.feedbackScore;
      if (e.degraded) degraded++;
      for (final t in _topicsOf(e.question)) {
        topicCount[t] = (topicCount[t] ?? 0) + 1;
      }
    }
    final topics = topicCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return MemoryStats(
      total: _entries.length,
      bySource: bySource,
      totalHits: totalHits,
      avgFeedback: _entries.isEmpty ? 0 : feedbackSum / _entries.length,
      topTopics: topics.take(5).toList(),
      degradedCount: degraded,
    );
  }

  bool containsSimilar(String question) => lookupEntry(question) != null;

  // ─────────────────────────── صادرات/واردات ───────────────────────────

  String exportJson() =>
      jsonEncode({
        'version': 2,
        'entries': _entries.map((k, v) => MapEntry(k, v.toJson())),
      });

  Future<void> importJson(String json, {bool merge = true}) async {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        if (!merge) _entries.clear();
        final entriesRaw = decoded['entries'];
        if (decoded['version'] == 2 && entriesRaw is Map<String, dynamic>) {
          for (final e in entriesRaw.entries) {
            if (e.value is Map<String, dynamic>) {
              final entry = MemoryEntry.fromJson(
                Map<String, dynamic>.from(e.value as Map),
              );
              if (entry.question.isNotEmpty && entry.answer.trim().isNotEmpty) {
                _entries[_normalize(entry.question)] = entry;
              }
            }
          }
        } else {
          // نسخهٔ ۱ یا نقشهٔ ساده
          final now = DateTime.now();
          for (final e in decoded.entries) {
            final q = _normalize(e.key);
            if (q.isEmpty) continue;
            _entries[q] = MemoryEntry(
              question: q,
              answer: e.value.toString(),
              source: MemorySource.import,
              createdAt: now,
            );
          }
        }
        _evictIfNeeded();
        await _save();
      }
    } catch (_) {}
  }

  /// پاک کردن کل حافظه.
  Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  @visibleForTesting
  void reset() {
    _entries.clear();
    _loaded = false;
  }

  // ─────────────────────────── ابزار داخلی ───────────────────────────

  /// نرمال‌سازی سؤال (عمومی برای استفادهٔ بیرونی).
  String normalizeQuestion(String s) => _normalize(s);

  /// حذف ضعیف‌ترین‌ها وقتی ظرفیت پر شود — بر اساس «ارزش»:
  /// کمترین استفاده + قدیمی‌ترین زمان استفاده، نه ترتیب ورود.
  void _evictIfNeeded() {
    if (_entries.length <= _maxEntries) return;
    final ordered = _entries.values.toList()
      ..sort((a, b) {
        final byUse = a.useCount.compareTo(b.useCount);
        if (byUse != 0) return byUse;
        return a.lastUsedAt.compareTo(b.lastUsedAt);
      });
    final toRemove = ordered.take(_entries.length - _maxEntries);
    for (final e in toRemove) {
      _entries.remove(e.question);
    }
  }

  /// امتیاز شباهت با رتبه‌بندی: کیفیت (بازخورد) + تازگی به عنوان تای‌بریکر.
  double _rankedSimilarity(String a, MemoryEntry entry) {
    final base = _similarity(a, entry.question);
    var score = base;
    // ورودی‌های پراستفاده کمی برتری می‌گیرند (حداکثر +۰.۰۵)
    score += min(0.05, entry.useCount * 0.005);
    // تازگی: استفاده در ۲۴ ساعت اخیر کمی برتری دارد
    final age = DateTime.now().difference(entry.lastUsedAt);
    if (age.inHours < 24) score += 0.02;
    return score.clamp(0.0, 1.0);
  }

  /// استخراج موضوع‌ها از یک سؤال نرمال‌شده (حذف کلمات ایست).
  List<String> _topicsOf(String question) {
    const stopwords = {
      'برای', 'چه', 'چطور', 'چگونه', 'چرا', 'چیست', 'چیه', 'چقدره', 'چقدر',
      'چند', 'که', 'به', 'از', 'در', 'با', 'من', 'تو', 'ما', 'شما', 'می',
      'رو', 'یه', 'یک', 'این', 'آن', 'بود', 'هست', 'هستم', 'دارم', 'میخوام',
      'میشه', 'کردن', 'کرد', 'کنم', 'کنی', 'بده', 'بگو', 'سلام', 'لطفا',
      'آیا', 'یا', 'نه', 'بله', 'آره', 'خب', 'و', 'را', 'هم', 'نیست',
      'ندارم', 'باید', 'میتونم', 'میتونی', 'الان', 'حالا', 'کردم', 'کردی',
      'کند', 'شود', 'باشه', 'درباره', 'برام', 'برات', 'خواستم',
      'دلم', 'بنویسم', 'یادداشت', 'ثبت', 'کن', 'میکنم', 'بزن',
      'بذار', 'بزار', 'بشه',
    };
    final words = question
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && !stopwords.contains(w));
    return words.toSet().toList();
  }

  String _normalize(String s) {
    var text = s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u200c\u200f\u200e]'), '') // نیم‌فاصله
        .replaceAll(RegExp(r'[،,.!؟?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // اصلاح فاصله‌گذاری بدهکار
    text = text.replaceAll(RegExp(r'بده\s+کار'), 'بدهکار');
    // یکسان‌سازی هم‌معناها برای تطبیق معنایی
    text = _expandSynonyms(text);
    return text;
  }

  /// نگاشت هم‌معناها به یک فرم کانونی برای تطبیق معنایی بهتر
  /// مثلاً «قرض» و «وام» → «بدهی»، «حساب/پرونده/مانده» → «بدهی»
  ///
  /// توجه: چون \b در regex دارت برای حروف فارسی کار نمی‌کند، جایگزینی
  /// به‌صورت توکن‌به‌توکن انجام می‌شود (نه replaceAll با \b).
  String _expandSynonyms(String s) {
    const synMap = {
      'قرض': 'بدهی',
      'وام': 'بدهی',
      'بدهکاری': 'بدهی',
      'بدهکارم': 'بدهی',
      'بدهکار': 'بدهی',
      'طلب': 'بدهی',
      'طلبکار': 'بدهی',
      'حساب': 'بدهی',
      'پرونده': 'بدهی',
      'مانده': 'بدهی',
      'چقدره': 'چقدر',
      'چنده': 'چقدر',
      'چند': 'چقدر',
    };
    return s
        .split(RegExp(r'\s+'))
        .map((w) => synMap[w] ?? w)
        .join(' ');
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;

    // اگر شخص متفاوت باشد، امتیاز را کم کن (فرهاد vs مریم نباید یکی شود)
    final personA = _extractPersonToken(a);
    final personB = _extractPersonToken(b);
    final personMismatch =
        personA != null && personB != null && personA != personB;

    // ۱) جاکارد روی کلمات (مثل قبل) — وزن ۰.۵
    final setA = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final setB = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    double jaccard = 0.0;
    if (setA.isNotEmpty && setB.isNotEmpty) {
      final inter = setA.intersection(setB).length;
      final union = setA.union(setB).length;
      jaccard = union == 0 ? 0.0 : inter / union;
    }

    // ۲) TF-IDF cosine روی تکرار کلمات — وزن ۰.۳ (برای سؤالات طولانی‌تر دقیق‌تر)
    final tfidf = _tfidfCosine(a, b);

    // ۳) شباهت کاراکتری (برای غلط املایی جزئی) — وزن ۰.۲
    final charSim = _charBigramSimilarity(a, b);

    var score = jaccard * 0.5 + tfidf * 0.3 + charSim * 0.2;

    // اگر شخص متفاوت بود، ۰.۲۵ کم کن
    if (personMismatch) score -= 0.25;

    // اگر یکی زیرمجموعه دیگری بود (مثلاً «بدهی فرهاد» در «بدهی فرهاد چقدره؟») امتیاز بده
    if (a.contains(b) || b.contains(a)) score = (score + 0.15).clamp(0.0, 1.0);

    return score.clamp(0.0, 1.0);
  }

  String? _extractPersonToken(String s) {
    // ساده: آخرین کلمه فارسی ۲-۱۵ حرفی که اسم باشد (نه کلمه عمومی)
    final words = s.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    const common = [
      'بدهی', 'چقدر', 'حساب', 'امروز', 'فردا', 'سلام', 'پرداخت',
      // کلمات سؤالی نباید اسم (شخص) تشخیص داده شوند
      'چیست', 'چیه', 'است', 'کجا', 'کی', 'چه', 'چطور', 'چگونه', 'چنده',
      'چند', 'میخوام', 'میشه', 'میتونم',
    ];
    for (final w in words.reversed) {
      if (RegExp(r'^[\u0600-\u06FF]{2,15}$').hasMatch(w) &&
          !common.contains(w)) {
        return w;
      }
    }
    return null;
  }

  double _tfidfCosine(String a, String b) {
    final tokensA = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    final tokensB = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
    final all = {...tokensA, ...tokensB}.toList();
    final vecA = all
        .map((t) => tokensA.where((x) => x == t).length.toDouble())
        .toList();
    final vecB = all
        .map((t) => tokensB.where((x) => x == t).length.toDouble())
        .toList();
    double dot = 0, magA = 0, magB = 0;
    for (var i = 0; i < all.length; i++) {
      dot += vecA[i] * vecB[i];
      magA += vecA[i] * vecA[i];
      magB += vecB[i] * vecB[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (sqrt(magA) * sqrt(magB) + 1e-9);
  }

  double _charBigramSimilarity(String a, String b) {
    Set<String> bigrams(String s) {
      final s2 = s.replaceAll(' ', '');
      if (s2.length < 2) return {s2};
      final set = <String>{};
      for (var i = 0; i < s2.length - 1; i++) {
        set.add(s2.substring(i, i + 2));
      }
      return set;
    }

    final setA = bigrams(a);
    final setB = bigrams(b);
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final inter = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0.0 : inter / union;
  }
}
