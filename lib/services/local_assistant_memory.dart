import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حافظهٔ یادگیری محلی دستیار.
///
/// وقتی دستیار از هوش آنلاین یک پاسخ می‌گیرد، «سؤال → جواب» را در حافظه
/// (روی دستگاه) ذخیره می‌کند. دفعهٔ بعد که کاربر همان/سؤال مشابهی بپرسد،
/// دستیار مستقیم از محلی جواب می‌دهد (سریع‌تر، رایگان و بدون نیاز به آنلاین).
class LocalAssistantMemory {
  LocalAssistantMemory._();
  static final LocalAssistantMemory instance = LocalAssistantMemory._();

  static const _prefKey = 'local_assistant_memory';
  static const _maxEntries = 200;

  /// نگاشت «سؤال نرمال‌شده → جواب».
  final Map<String, String> _entries = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _entries
            ..clear()
            ..addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_entries));
    } catch (_) {}
  }

  /// آیا این سؤال از قبل در حافظه است؟ (با تطبیق دقیق یا فازی)
  String? lookup(String question) {
    final norm = _normalize(question);
    if (norm.isEmpty) return null;

    // ۱) تطبیق دقیق
    final exact = _entries[norm];
    if (exact != null) return exact;

    // ۲) تطبیق فازی معنایی — Jaccard + TF-IDF + هم‌معناها + شخص
    String? bestMatch;
    var bestScore = 0.0;
    for (final entry in _entries.entries) {
      final score = _similarity(norm, entry.key);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry.value;
      }
    }
    if (bestScore >= 0.68) return bestMatch;
    return null;
  }

  /// ذخیرهٔ یک «سؤال → جواب» در حافظه.
  Future<void> remember(String question, String answer) async {
    final norm = _normalize(question);
    if (norm.isEmpty || answer.trim().isEmpty) return;
    _entries[norm] = answer.trim();
    if (_entries.length > _maxEntries) {
      // حذف قدیمی‌ترین‌ها (اولین‌ها)
      final keys = _entries.keys.toList();
      final toRemove = keys.length - _maxEntries;
      for (var i = 0; i < toRemove; i++) {
        _entries.remove(keys[i]);
      }
    }
    await _save();
  }

  /// تعداد پاسخ‌های یادگرفته‌شده.
  int get count => _entries.length;

  /// پاک کردن کل حافظه (برای تست و تنظیمات).
  Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  @visibleForTesting
  void reset() {
    _entries.clear();
    _loaded = false;
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
      'چند': 'چقدر',
    };
    var out = s;
    synMap.forEach((k, v) {
      out = out.replaceAll(RegExp('\\b$k\\b'), v);
    });
    return out;
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;

    // اگر شخص متفاوت باشد، امتیاز را کم کن (فرهاد vs مریم نباید یکی شود)
    final personA = _extractPersonToken(a);
    final personB = _extractPersonToken(b);
    final personMismatch = personA != null && personB != null && personA != personB;

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
    const common = ['بدهی', 'چقدر', 'حساب', 'امروز', 'فردا', 'سلام', 'پرداخت'];
    for (final w in words.reversed) {
      if (RegExp(r'^[\u0600-\u06FF]{2,15}$').hasMatch(w) && !common.contains(w)) {
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
    final vecA = all.map((t) => tokensA.where((x) => x == t).length.toDouble()).toList();
    final vecB = all.map((t) => tokensB.where((x) => x == t).length.toDouble()).toList();
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
