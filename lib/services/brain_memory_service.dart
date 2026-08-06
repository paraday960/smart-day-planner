import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/finance_transaction.dart';

/// 🧠 حافظه بلندمدت مغز — ماه‌ها یادش می‌مونه
/// 
/// با SharedPreferences ذخیره می‌شود، حتی بعد از بستن برنامه پاک نمی‌شود.
/// هر بار مغز تحلیل می‌کند، این حافظه آپدیت می‌شود.

class BrainLongTermMemory {
  const BrainLongTermMemory({
    this.favoriteCategory,
    this.hatedCategory,
    this.mostProductiveHour,
    this.leastProductiveHour,
    this.avgCompletionRate = 0,
    this.totalAnalyses = 0,
    this.categoryStats = const {},
    this.weeklyIncomeAvg = 0,
    this.lastUpdated,
    this.userName,
    this.preferredWorkHours,
  });

  final String? favoriteCategory; // دسته‌ای که بیشتر و سریع‌تر تموم می‌کنی
  final String? hatedCategory; // دسته‌ای که بیشتر عقب می‌افته
  final int? mostProductiveHour;
  final int? leastProductiveHour;
  final double avgCompletionRate;
  final int totalAnalyses;
  /// آمار هر دسته: {category: {completed: 5, overdue: 1, avgRatio: 1.2}}
  final Map<String, Map<String, dynamic>> categoryStats;
  final double weeklyIncomeAvg;
  final DateTime? lastUpdated;
  final String? userName;
  final String? preferredWorkHours; // مثلا "۹ تا ۱۸"

  Map<String, dynamic> toJson() => {
    'favoriteCategory': favoriteCategory,
    'hatedCategory': hatedCategory,
    'mostProductiveHour': mostProductiveHour,
    'leastProductiveHour': leastProductiveHour,
    'avgCompletionRate': avgCompletionRate,
    'totalAnalyses': totalAnalyses,
    'categoryStats': categoryStats,
    'weeklyIncomeAvg': weeklyIncomeAvg,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'userName': userName,
    'preferredWorkHours': preferredWorkHours,
  };

  factory BrainLongTermMemory.fromJson(Map<String, dynamic> json) {
    return BrainLongTermMemory(
      favoriteCategory: json['favoriteCategory'] as String?,
      hatedCategory: json['hatedCategory'] as String?,
      mostProductiveHour: json['mostProductiveHour'] as int?,
      leastProductiveHour: json['leastProductiveHour'] as int?,
      avgCompletionRate: (json['avgCompletionRate'] as num?)?.toDouble() ?? 0,
      totalAnalyses: json['totalAnalyses'] as int? ?? 0,
      categoryStats: (json['categoryStats'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map))
      ) ?? {},
      weeklyIncomeAvg: (json['weeklyIncomeAvg'] as num?)?.toDouble() ?? 0,
      lastUpdated: json['lastUpdated'] != null ? DateTime.tryParse(json['lastUpdated']) : null,
      userName: json['userName'] as String?,
      preferredWorkHours: json['preferredWorkHours'] as String?,
    );
  }

  String get summary {
    if (totalAnalyses == 0) return 'هنوز حافظه‌ای شکل نگرفته';
    final parts = <String>[];
    if (favoriteCategory != null) parts.add('علاقه: $favoriteCategory');
    if (hatedCategory != null) parts.add('چالش: $hatedCategory');
    if (mostProductiveHour != null) parts.add('اوج: ${mostProductiveHour}:۰۰');
    parts.add('تحلیل: $totalAnalyses بار');
    return parts.join(' • ');
  }
}

class BrainMemoryService {
  static const _key = 'ai_brain_long_term_memory_v1';
  static const _historyKey = 'ai_brain_history_v1';

  /// بارگذاری از حافظه گوشی
  Future<BrainLongTermMemory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return const BrainLongTermMemory();
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return BrainLongTermMemory.fromJson(map);
    } catch (_) {
      return const BrainLongTermMemory();
    }
  }

  /// ذخیره
  Future<void> save(BrainLongTermMemory memory) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(memory.toJson());
    await prefs.setString(_key, jsonStr);
  }

  /// پاک کردن (برای تست/ریست)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_historyKey);
  }

  /// یادگیری از داده‌های جدید و آپدیت حافظه
  Future<BrainLongTermMemory> learn({
    required List<Task> tasks,
    required List<FinanceTransaction> transactions,
    BrainLongTermMemory? current,
  }) async {
    final memory = current ?? await load();
    final now = DateTime.now();

    // دسته‌ها
    final completed = tasks.where((t) => t.isDone).toList();
    final overdue = tasks.where((t) => t.isOverdue).toList();
    
    String? favorite;
    String? hated;
    if (completed.isNotEmpty) {
      final byCat = <String, int>{};
      for (final t in completed) byCat.update(t.category, (v) => v + 1, ifAbsent: () => 1);
      favorite = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    if (overdue.isNotEmpty) {
      final byCat = <String, int>{};
      for (final t in overdue) byCat.update(t.category, (v) => v + 1, ifAbsent: () => 1);
      hated = byCat.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    // بهترین ساعت
    int? bestHour;
    int? worstHour;
    if (completed.length >= 3) {
      final byHour = <int, int>{};
      for (final t in completed.where((t) => t.completedAt != null)) {
        byHour.update(t.completedAt!.hour, (v) => v + 1, ifAbsent: () => 1);
      }
      if (byHour.isNotEmpty) {
        bestHour = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        if (byHour.length > 1) {
          worstHour = byHour.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
        }
      }
    }

    // نرخ تکمیل میانگین متحرک
    final total = tasks.length;
    final rate = total == 0 ? 0.0 : completed.length / total;
    // میانگین با حافظه قبلی (EMA با alpha=0.3)
    final newRate = memory.totalAnalyses == 0 ? rate : memory.avgCompletionRate * 0.7 + rate * 0.3;

    // میانگین درآمد هفتگی
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekIncome = transactions
        .where((t) => t.type == FinanceTransactionType.income && t.createdAt.isAfter(weekAgo))
        .fold<int>(0, (s, t) => s + t.amount);
    final newWeeklyAvg = memory.totalAnalyses == 0 ? weekIncome.toDouble() : memory.weeklyIncomeAvg * 0.7 + weekIncome * 0.3;

    // آمار دسته‌ها
    final newStats = Map<String, Map<String, dynamic>>.from(memory.categoryStats);
    for (final t in tasks) {
      final cat = t.category;
      newStats.putIfAbsent(cat, () => {'completed': 0, 'overdue': 0, 'total': 0});
      newStats[cat]!['total'] = (newStats[cat]!['total'] as int) + 1;
      if (t.isDone) newStats[cat]!['completed'] = (newStats[cat]!['completed'] as int) + 1;
      if (t.isOverdue) newStats[cat]!['overdue'] = (newStats[cat]!['overdue'] as int) + 1;
    }

    final updated = BrainLongTermMemory(
      favoriteCategory: favorite ?? memory.favoriteCategory,
      hatedCategory: hated ?? memory.hatedCategory,
      mostProductiveHour: bestHour ?? memory.mostProductiveHour,
      leastProductiveHour: worstHour ?? memory.leastProductiveHour,
      avgCompletionRate: newRate,
      totalAnalyses: memory.totalAnalyses + 1,
      categoryStats: newStats,
      weeklyIncomeAvg: newWeeklyAvg,
      lastUpdated: now,
      userName: memory.userName,
      preferredWorkHours: memory.preferredWorkHours,
    );

    await save(updated);
    await _appendHistory(rate, weekIncome);
    return updated;
  }

  Future<void> _appendHistory(double rate, int weeklyIncome) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    final entry = jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'rate': rate,
      'income': weeklyIncome,
    });
    list.add(entry);
    // نگه‌داری فقط ۹۰ روز آخر
    if (list.length > 90) list.removeAt(0);
    await prefs.setStringList(_historyKey, list);
  }

  /// تاریخچه برای نمودار
  Future<List<Map<String, dynamic>>> history() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    return list.map((e) {
      try { return jsonDecode(e) as Map<String, dynamic>; } catch (_) { return <String,dynamic>{}; }
    }).where((e) => e.isNotEmpty).toList();
  }
}
