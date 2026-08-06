import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/planned_expense_repository_port.dart';
import '../models/planned_expense_goal.dart';

class PlannedExpenseRepository extends ChangeNotifier implements PlannedExpenseRepositoryPort {
  static const _storageKey = 'smart_day_planner.planned_expenses.v1';

  final List<PlannedExpenseGoal> _items = [];
  bool _loaded = false;

  @override
  List<PlannedExpenseGoal> get items => List.unmodifiable(_items);
  @override
  List<PlannedExpenseGoal> get activeItems => _items.where((e) => e.isActive).toList()
    ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(decoded.map((e) => PlannedExpenseGoal.fromJson(e as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> add(PlannedExpenseGoal item) async {
    _items.add(item);
    await _save();
  }

  @override
  Future<void> update(PlannedExpenseGoal item) async {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    _items[index] = item;
    await _save();
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
  }

  @override
  Future<void> markDone(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(status: PlannedExpenseStatus.done);
    await _save();
  }

  @override
  Future<void> replaceAll(List<PlannedExpenseGoal> items) async {
    _items
      ..clear()
      ..addAll(items);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
}
