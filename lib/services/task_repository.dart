import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/repositories/task_repository_port.dart';
import '../models/task.dart';
import 'database_service.dart';
import 'app_trace.dart';

class TaskRepository extends ChangeNotifier implements TaskRepositoryPort {
  static const _legacyStorageKey = 'smart_day_planner.tasks.v1';
  static const _seededKey = 'smart_day_planner.tasks.seeded.sqlite.v1';

  final List<Task> _tasks = [];
  bool _loaded = false;

  @override
  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get loaded => _loaded;

  Future<void> load() async {
    final db = await DatabaseService.instance.database;
    await _migrateLegacyOrSeedIfNeeded(db);
    await _refreshFromDb(db);

    _loaded = true;
    notifyListeners();
  }

  @override
  Future<void> add(Task task) => AppTrace.instance.track(
        'task',
        'افزودن کار: ${task.title}',
        () => _addImpl(task),
      );

  Future<void> _addImpl(Task task) async {
    final db = await DatabaseService.instance.database;
    await _upsert(db, task);
    await _refreshAndNotify(db);
  }

  @override
  Future<void> update(Task task) => AppTrace.instance.track(
        'task', 'به‌روزرسانی کار: ${task.title}',
        () => _updateImpl(task));
  Future<void> _updateImpl(Task task) async {
    final db = await DatabaseService.instance.database;
    await _upsert(db, task);
    await _refreshAndNotify(db);
  }

  @override
  Future<void> delete(String id) => AppTrace.instance.track(
        'task', 'حذف کار',
        () => _deleteImpl(id));
  Future<void> _deleteImpl(String id) async {
    final db = await DatabaseService.instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await _refreshAndNotify(db);
  }

  @override
  Future<void> replaceAll(List<Task> tasks) async {
    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    batch.delete('tasks');
    for (final task in tasks) {
      batch.insert('tasks', _toRow(task), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _refreshAndNotify(db);
  }

  @override
  Future<void> togglePin(String id) async {
    final task = _findById(id);
    if (task == null) return;
    await update(task.copyWith(isPinned: !task.isPinned));
  }

  @override
  Future<void> complete(String id, {required int actualMinutes}) =>
      AppTrace.instance.track(
        'task', 'تکمیل کار',
        () => _completeImpl(id, actualMinutes: actualMinutes));
  Future<void> _completeImpl(String id, {required int actualMinutes}) async {
    final task = _findById(id);
    if (task == null) return;
    await update(
      task.copyWith(
        status: TaskStatus.done,
        actualMinutes: actualMinutes,
        completedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> reopen(String id) async {
    final task = _findById(id);
    if (task == null) return;
    await update(
      task.copyWith(
        status: TaskStatus.todo,
        clearActualMinutes: true,
        clearCompletedAt: true,
      ),
    );
  }

  Task? _findById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> _migrateLegacyOrSeedIfNeeded(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks')) ?? 0;
    if (count > 0) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadySeeded = prefs.getBool(_seededKey) ?? false;
    if (alreadySeeded) return;

    final legacyRaw = prefs.getString(_legacyStorageKey);
    final tasksToInsert = <Task>[];

    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      final decoded = jsonDecode(legacyRaw) as List<dynamic>;
      tasksToInsert.addAll(decoded.map((e) => Task.fromJson(e as Map<String, dynamic>)));
    } else {
      tasksToInsert.addAll(_sampleTasks());
    }

    final batch = db.batch();
    for (final task in tasksToInsert) {
      batch.insert('tasks', _toRow(task), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await prefs.setBool(_seededKey, true);
  }

  Future<void> _refreshAndNotify(Database db) async {
    await _refreshFromDb(db);
    notifyListeners();
  }

  Future<void> _refreshFromDb(Database db) async {
    final rows = await db.query('tasks', orderBy: 'created_at DESC');
    _tasks
      ..clear()
      ..addAll(rows.map(_fromRow));
  }

  Future<void> _upsert(Database db, Task task) async {
    await db.insert(
      'tasks',
      _toRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, Object?> _toRow(Task task) => {
        'id': task.id,
        'title': task.title,
        'category': task.category,
        'status': task.status.name,
        'importance': task.importance,
        'due_at': task.dueAt?.toIso8601String(),
        'created_at': task.createdAt.toIso8601String(),
        'payload': jsonEncode(task.toJson()),
      };

  Task _fromRow(Map<String, Object?> row) {
    return Task.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>);
  }

  List<Task> _sampleTasks() {
    final now = DateTime.now();
    return [
      Task(
        id: 'sample-1',
        title: 'مرتب کردن برنامه امروز',
        notes: 'نمونه کار برای شروع. می‌توانی حذفش کنی.',
        category: 'برنامه‌ریزی',
        createdAt: now,
        dueAt: now.add(const Duration(hours: 3)),
        importance: 4,
        energy: EnergyLevel.low,
        estimatedMinutes: 20,
      ),
      Task(
        id: 'sample-2',
        title: 'تمرکز روی مهم‌ترین پروژه',
        category: 'کار',
        createdAt: now.subtract(const Duration(days: 1)),
        dueAt: now.add(const Duration(days: 1)),
        importance: 5,
        energy: EnergyLevel.high,
        estimatedMinutes: 90,
      ),
    ];
  }
}
