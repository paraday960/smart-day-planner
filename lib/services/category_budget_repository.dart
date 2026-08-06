import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/category_budget_repository_port.dart';
import '../models/category_budget.dart';

class CategoryBudgetRepository extends ChangeNotifier implements CategoryBudgetRepositoryPort {
  static const _storageKey = 'smart_day_planner.category_budgets.v1';

  final List<CategoryBudget> _items = [];
  bool _loaded = false;

  List<CategoryBudget> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(decoded.map((e) => CategoryBudget.fromJson(e as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  CategoryBudget? budgetFor(String category) {
    for (final item in _items) {
      if (item.category == category) return item;
    }
    return null;
  }

  Future<void> upsert(String category, int monthlyLimit) async {
    final index = _items.indexWhere((e) => e.category == category);
    final item = CategoryBudget(
      id: index == -1 ? DateTime.now().microsecondsSinceEpoch.toString() : _items[index].id,
      category: category,
      monthlyLimit: monthlyLimit,
      createdAt: index == -1 ? DateTime.now() : _items[index].createdAt,
    );
    if (index == -1) {
      _items.add(item);
    } else {
      _items[index] = item;
    }
    await _save();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> replaceAll(List<CategoryBudget> items) async {
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
