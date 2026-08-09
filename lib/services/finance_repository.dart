import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/repositories/finance_repository_port.dart';
import '../models/finance_transaction.dart';
import 'database_service.dart';
import 'app_trace.dart';

class FinanceRepository extends ChangeNotifier implements FinanceRepositoryPort {
  static const _legacyStorageKey = 'smart_day_planner.finance.v1';
  static const _migratedKey = 'smart_day_planner.finance.migrated.sqlite.v1';

  final List<FinanceTransaction> _transactions = [];
  bool _loaded = false;

  @override
  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);
  bool get loaded => _loaded;

  Future<void> load() async {
    final db = await DatabaseService.instance.database;
    await _migrateLegacyIfNeeded(db);
    await _refreshFromDb(db);

    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> add(FinanceTransaction transaction) async {
    final sw = Stopwatch()..start();
    try {
      await _addImpl(transaction);
      sw.stop();
      AppTrace.instance.log(
        AppCategory.finance,
        transaction.type == FinanceTransactionType.income ? 'درآمد ثبت شد' : 'هزینه ثبت شد',
        source: 'finance_repository.dart:add',
        inputs: {'amount': transaction.amount, 'type': transaction.type.toString(), 'title': transaction.note},
        outputs: {'stored': true},
        duration: sw.elapsed, level: TraceLevel.success);
    } catch(e) {
      sw.stop();
      AppTrace.instance.log(AppCategory.finance, 'خطا در ثبت تراکنش', source: 'finance_repository.dart:add', duration: sw.elapsed, level: TraceLevel.error, error: e.toString());
      rethrow;
    }
  }
  Future<void> _addImpl(FinanceTransaction transaction) async {
    final db = await DatabaseService.instance.database;
    await db.insert('finance_transactions', _toRow(transaction), conflictAlgorithm: ConflictAlgorithm.replace);
    await _refreshAndNotify(db);
  }

  @override
  Future<void> delete(String id) async {
    final sw = Stopwatch()..start();
    try {
      await _deleteImpl(id);
      sw.stop();
      AppTrace.instance.log(AppCategory.finance, 'تراکنش حذف شد', source: 'finance_repository.dart:delete', duration: sw.elapsed, level: TraceLevel.success, outputs: {'deleted': true});
    } catch(e) {
      sw.stop();
      AppTrace.instance.log(AppCategory.finance, 'خطا در حذف تراکنش', source: 'finance_repository.dart:delete', duration: sw.elapsed, level: TraceLevel.error, error: e.toString());
      rethrow;
    }
  }
  Future<void> _deleteImpl(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('finance_transactions', where: 'id = ?', whereArgs: [id]);
    await _refreshAndNotify(db);
  }

  @override
  Future<void> replaceAll(List<FinanceTransaction> transactions) async {
    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    batch.delete('finance_transactions');
    for (final transaction in transactions) {
      batch.insert('finance_transactions', _toRow(transaction), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _refreshAndNotify(db);
  }

  int total({FinanceTransactionType? type, DateTime? from, DateTime? to}) {
    return filtered(type: type, from: from, to: to).fold(0, (sum, t) => sum + t.amount);
  }

  int net({DateTime? from, DateTime? to}) {
    return filtered(from: from, to: to).fold(0, (sum, t) => sum + t.signedAmount);
  }

  List<FinanceTransaction> filtered({FinanceTransactionType? type, DateTime? from, DateTime? to}) {
    return _transactions.where((t) {
      if (type != null && t.type != type) return false;
      if (from != null && t.createdAt.isBefore(from)) return false;
      if (to != null && !t.createdAt.isBefore(to)) return false;
      return true;
    }).toList();
  }

  Map<String, int> totalsByCategory({required FinanceTransactionType type, DateTime? from, DateTime? to}) {
    final result = <String, int>{};
    for (final transaction in filtered(type: type, from: from, to: to)) {
      result.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final sorted = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in sorted) entry.key: entry.value};
  }

  int incomeToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return total(type: FinanceTransactionType.income, from: start, to: end);
  }

  int expenseToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return total(type: FinanceTransactionType.expense, from: start, to: end);
  }

  int incomeThisWeek() {
    final range = _currentIranianWeekRange();
    return total(type: FinanceTransactionType.income, from: range.start, to: range.end);
  }

  int expenseThisWeek() {
    final range = _currentIranianWeekRange();
    return total(type: FinanceTransactionType.expense, from: range.start, to: range.end);
  }

  int incomeThisMonth() {
    final range = _currentJalaliMonthRange();
    return total(type: FinanceTransactionType.income, from: range.start, to: range.end);
  }

  int expenseThisMonth() {
    final range = _currentJalaliMonthRange();
    return total(type: FinanceTransactionType.expense, from: range.start, to: range.end);
  }

  int netThisMonth() {
    final range = _currentJalaliMonthRange();
    return net(from: range.start, to: range.end);
  }

  _DateRange _currentIranianWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // هفته ایرانی از شنبه شروع می‌شود. DateTime.weekday: شنبه = ۶، یکشنبه = ۷، دوشنبه = ۱...
    final daysFromSaturday = now.weekday == DateTime.saturday ? 0 : (now.weekday + 1) % 7;
    final start = today.subtract(Duration(days: daysFromSaturday));
    return _DateRange(start: start, end: start.add(const Duration(days: 7)));
  }

  _DateRange _currentJalaliMonthRange() {
    final nowJalali = Jalali.now();
    final startG = Jalali(nowJalali.year, nowJalali.month).toGregorian();
    final nextMonth = nowJalali.month == 12
        ? Jalali(nowJalali.year + 1, 1)
        : Jalali(nowJalali.year, nowJalali.month + 1);
    final endG = nextMonth.toGregorian();
    return _DateRange(
      start: DateTime(startG.year, startG.month, startG.day),
      end: DateTime(endG.year, endG.month, endG.day),
    );
  }

  DateTime currentJalaliMonthStart() => _currentJalaliMonthRange().start;
  DateTime currentJalaliMonthEnd() => _currentJalaliMonthRange().end;

  double averageHourlyRate() {
    final rates = _transactions
        .where((t) => t.type == FinanceTransactionType.income && t.hourlyRate != null)
        .map((t) => t.hourlyRate!)
        .toList();
    if (rates.isEmpty) return 0;
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  Future<void> _migrateLegacyIfNeeded(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;
    if (alreadyMigrated) return;

    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM finance_transactions')) ?? 0;
    if (count > 0) {
      await prefs.setBool(_migratedKey, true);
      return;
    }

    final legacyRaw = prefs.getString(_legacyStorageKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      final decoded = jsonDecode(legacyRaw) as List<dynamic>;
      final batch = db.batch();
      for (final transaction in decoded.map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))) {
        batch.insert('finance_transactions', _toRow(transaction), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }

    await prefs.setBool(_migratedKey, true);
  }

  Future<void> _refreshAndNotify(Database db) async {
    await _refreshFromDb(db);
    notifyListeners();
  }

  Future<void> _refreshFromDb(Database db) async {
    final rows = await db.query('finance_transactions', orderBy: 'created_at DESC');
    _transactions
      ..clear()
      ..addAll(rows.map(_fromRow));
  }

  Map<String, Object?> _toRow(FinanceTransaction transaction) => {
        'id': transaction.id,
        'type': transaction.type.name,
        'amount': transaction.amount,
        'category': transaction.category,
        'created_at': transaction.createdAt.toIso8601String(),
        'task_id': transaction.taskId,
        'payload': jsonEncode(transaction.toJson()),
      };

  FinanceTransaction _fromRow(Map<String, Object?> row) {
    return FinanceTransaction.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>);
  }
}

class _DateRange {
  const _DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
