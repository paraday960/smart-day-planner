import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/allocation_repository_port.dart';
import '../models/money_allocation.dart';

class AllocationRepository extends ChangeNotifier implements AllocationRepositoryPort {
  static const _storageKey = 'smart_day_planner.allocations.v1';

  final List<MoneyAllocation> _items = [];
  bool _loaded = false;

  @override
  List<MoneyAllocation> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(decoded.map((e) => MoneyAllocation.fromJson(e as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  int totalFor(AllocationTargetType targetType, String targetId) {
    return _items
        .where((e) => e.targetType == targetType && e.targetId == targetId)
        .fold<int>(0, (sum, e) => sum + e.amount);
  }

  @override
  int totalAllocated() => _items.fold<int>(0, (sum, e) => sum + e.amount);

  @override
  Future<void> add(MoneyAllocation allocation) async {
    _items.add(allocation);
    await _save();
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
  }

  @override
  Future<void> replaceAll(List<MoneyAllocation> items) async {
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
