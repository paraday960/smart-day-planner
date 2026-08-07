import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  Future<Database>? _databaseFuture;

  /// دیتابیس مشترک همهٔ repositoryها.
  ///
  /// اگر چند فراخوانی به‌طور همزمان (مثلاً هنگام موازی‌سازی load در استارتاپ)
  /// این getter را صدا بزنند، همهٔ آن‌ها روی **همان** [Future] بازکردن دیتابیس
  /// منتظر می‌مانند و فقط یک‌بار `openDatabase` اجرا می‌شود؛ در غیر این صورت
  /// چند اتصال همزمان به یک فایل sqflite می‌تواند خطای «database is locked»
  /// ایجاد کند.
  Future<Database> get database {
    final existing = _databaseFuture;
    if (existing != null) return existing;
    final future = _open();
    _databaseFuture = future;
    return future;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'smart_day_planner.db');

    try {
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
      );
    } catch (_) {
      // اگر بازکردن دیتابیس شکست بخورد، کش را پاک می‌کنیم تا تلاش بعدی
      // بتواند دوباره تلاش کند (به‌جای باقی‌ماندن یک Future ناموفق).
      _databaseFuture = null;
      rethrow;
    }

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _databaseFuture = null;
  }
}
