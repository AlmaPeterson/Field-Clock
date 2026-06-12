import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fieldclock.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          work_day_id INTEGER NOT NULL,
          clock_in_time TEXT NOT NULL,
          clock_in_photo TEXT,
          clock_in_location TEXT,
          clock_out_time TEXT,
          clock_out_photo TEXT,
          clock_out_location TEXT,
          duration_minutes INTEGER DEFAULT 0,
          FOREIGN KEY (work_day_id) REFERENCES work_days(id)
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hourly_rate REAL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        client_name TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT,
        status TEXT DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE work_days (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id INTEGER,
        date TEXT NOT NULL,
        clock_in_time TEXT,
        clock_in_photo TEXT,
        clock_in_location TEXT,
        clock_out_time TEXT,
        clock_out_photo TEXT,
        clock_out_location TEXT,
        total_minutes_raw INTEGER DEFAULT 0,
        total_minutes_rounded INTEGER DEFAULT 0,
        FOREIGN KEY (job_id) REFERENCES jobs(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_day_id INTEGER NOT NULL,
        clock_in_time TEXT NOT NULL,
        clock_in_photo TEXT,
        clock_in_location TEXT,
        clock_out_time TEXT,
        clock_out_photo TEXT,
        clock_out_location TEXT,
        duration_minutes INTEGER DEFAULT 0,
        FOREIGN KEY (work_day_id) REFERENCES work_days(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_day_id INTEGER NOT NULL,
        name TEXT DEFAULT 'Unnamed Task',
        notes TEXT,
        start_time TEXT NOT NULL,
        start_photo TEXT,
        start_location TEXT,
        end_time TEXT,
        end_photo TEXT,
        end_location TEXT,
        duration_minutes_raw INTEGER DEFAULT 0,
        duration_minutes_rounded INTEGER DEFAULT 0,
        hourly_rate REAL DEFAULT 0.0,
        FOREIGN KEY (work_day_id) REFERENCES tasks(id)
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}