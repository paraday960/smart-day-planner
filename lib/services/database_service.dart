import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'smart_day_planner.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            status TEXT NOT NULL,
            importance INTEGER NOT NULL,
            due_at TEXT,
            created_at TEXT NOT NULL,
            payload TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE finance_transactions (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            category TEXT NOT NULL,
            created_at TEXT NOT NULL,
            task_id TEXT,
            payload TEXT NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
        await db.execute('CREATE INDEX idx_tasks_due_at ON tasks(due_at)');
        await db.execute('CREATE INDEX idx_finance_created_at ON finance_transactions(created_at)');
        await db.execute('CREATE INDEX idx_finance_type ON finance_transactions(type)');
      },
      // ── مسیر مهاجرت نسخه‌های آینده ──────────────────────────────
      // برای هر تغییر اسکیما: `version` را یکی بالا ببرید و یک بلوک
      // تدریجی (oldVersion < N) اینجا اضافه کنید:
      //
      //   if (oldVersion < 2) {
      //     await db.execute('ALTER TABLE tasks ADD COLUMN ...');
      //   }
      //
      // بدون این مسیر، اپ‌های نصب‌شده بعد از اولین تغییر اسکیما یا
      // کرش می‌کنند یا داده‌هایشان را از دست می‌دهند.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // اولین مهاجرت آینده اینجا اضافه می‌شود.
        }
      },
    );

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
