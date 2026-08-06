import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/debt_repository_port.dart';
import '../models/debt_item.dart';

class DebtRepository extends ChangeNotifier implements DebtRepositoryPort {
  static const _storageKey = 'smart_day_planner.debts.v1';

  final List<DebtItem> _items = [];
  bool _loaded = false;

  @override
  List<DebtItem> get items => List.unmodifiable(_items);
  @override
  List<DebtItem> get activeItems => _items.where((e) => e.isActive).toList()
    ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.addAll(decoded.map((e) => DebtItem.fromJson(e as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> add(DebtItem item) async {
    _items.add(item);
    await _save();
  }

  @override
  Future<void> update(DebtItem item) async {
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
  Future<void> addPayment(String id, int amount) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final item = _items[index];
    final paid = (item.paidAmount + amount).clamp(0, item.amount).toInt();
    _items[index] = item.copyWith(
      paidAmount: paid,
      status: paid >= item.amount ? DebtStatus.settled : item.status,
    );
    await _save();
  }

  @override
  Future<void> markSettled(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final item = _items[index];
    _items[index] = item.copyWith(paidAmount: item.amount, status: DebtStatus.settled);
    await _save();
  }

  @override
  Future<void> replaceAll(List<DebtItem> items) async {
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
