import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 👍👎 یادگیری از بازخورد کاربر
/// کاربر می‌گه "خوب بود" یا "بد بود" → مغز وزن پیشنهادها رو تنظیم می‌کنه

enum FeedbackType { positive, negative, neutral }

class FeedbackEntry {
  const FeedbackEntry({
    required this.suggestionType,
    required this.type,
    required this.date,
  });
  final String suggestionType; // مثلا "habit", "finance", "schedule"
  final FeedbackType type;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'suggestionType': suggestionType,
    'type': type.name,
    'date': date.toIso8601String(),
  };

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    suggestionType: json['suggestionType'] as String,
    type: FeedbackType.values.firstWhere((e) => e.name == json['type'], orElse: () => FeedbackType.neutral),
    date: DateTime.parse(json['date'] as String),
  );
}

class FeedbackLearningService {
  static const _key = 'ai_feedback_history_v1';
  static const _weightsKey = 'ai_feedback_weights_v1';

  /// ثبت بازخورد
  Future<void> recordFeedback({
    required String suggestionType,
    required FeedbackType type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    final entry = FeedbackEntry(suggestionType: suggestionType, type: type, date: DateTime.now());
    list.add(jsonEncode(entry.toJson()));
    if (list.length > 100) list.removeAt(0);
    await prefs.setStringList(_key, list);

    // آپدیت وزن‌ها
    final weights = await _loadWeights();
    final current = weights[suggestionType] ?? 1.0;
    if (type == FeedbackType.positive) {
      weights[suggestionType] = (current * 1.1).clamp(0.5, 2.0);
    } else if (type == FeedbackType.negative) {
      weights[suggestionType] = (current * 0.85).clamp(0.3, 2.0);
    }
    await prefs.setString(_weightsKey, jsonEncode(weights));
  }

  Future<Map<String, double>> _loadWeights() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_weightsKey);
    if (str == null) return {};
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return map.map((k,v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) { return {}; }
  }

  Future<Map<String, double>> getWeights() => _loadWeights();

  Future<List<FeedbackEntry>> history() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((e) {
      try { return FeedbackEntry.fromJson(jsonDecode(e) as Map<String,dynamic>); } catch(_){ return null; }
    }).whereType<FeedbackEntry>().toList();
  }

  /// تشخیص بازخورد از متن کاربر
  static FeedbackType detectFromText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('عالی') || lower.contains('خوب بود') || lower.contains('ممنون') || lower.contains('دمت گرم') || lower.contains('خوبه') || lower.contains('بد نبود') || lower.contains('👍')) {
      return FeedbackType.positive;
    }
    if (lower.contains('بد بود') || lower.contains('به درد نخورد') || lower.contains('مزخرف') || lower.contains('اشتباه') || lower.contains('بد') || lower.contains('👎') || lower.contains('نمی‌خوام')) {
      return FeedbackType.negative;
    }
    return FeedbackType.neutral;
  }

  /// آیا متن حاوی بازخورد است؟
  static bool isFeedback(String text) {
    final lower = text.toLowerCase();
    return lower.contains('خوب بود') || lower.contains('بد بود') || lower.contains('عالی') || lower.contains('به درد') || lower.contains('پیشنهاد') && (lower.contains('خوب') || lower.contains('بد'));
  }

  Future<String> feedbackSummary() async {
    final hist = await history();
    if (hist.isEmpty) return 'هنوز بازخوردی ثبت نشده';
    final pos = hist.where((e) => e.type == FeedbackType.positive).length;
    final neg = hist.where((e) => e.type == FeedbackType.negative).length;
    final weights = await getWeights();
    final buf = StringBuffer()
      ..writeln('📊 بازخوردها: $pos مثبت، $neg منفی از ${hist.length} نظر');
    if (weights.isNotEmpty) {
      buf.writeln('وزن‌ها: ${weights.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}').join(' • ')}');
    }
    return buf.toString();
  }
}
