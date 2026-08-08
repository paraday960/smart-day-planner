import 'dart:convert';

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

    // ۲) تطبیق فازی: اگر سؤال موجود زیرمجموعهٔ این سؤال باشد یا شباهت بالا
    //    داشته باشد. (برای سؤالات مشابهِ کوتاه)
    String? bestMatch;
    var bestScore = 0.0;
    for (final entry in _entries.entries) {
      final score = _similarity(norm, entry.key);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry.value;
      }
    }
    if (bestScore >= 0.7) return bestMatch;
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
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u200c\u200f\u200e]'), '') // نیم‌فاصله/فاصله
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    // جاکارد روی کلمات
    final setA = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final setB = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }
}
