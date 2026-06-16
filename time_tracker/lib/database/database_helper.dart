import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance =
      DatabaseHelper._init();
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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
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
          FOREIGN KEY (work_day_id)
            REFERENCES work_days(id)
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN division TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_photos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          photo_path TEXT NOT NULL,
          photo_type TEXT DEFAULT 'general',
          created_at TEXT NOT NULL,
          FOREIGN KEY (task_id) REFERENCES tasks(id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          start_time TEXT NOT NULL,
          start_photo TEXT,
          end_time TEXT,
          end_photo TEXT,
          duration_minutes_raw INTEGER DEFAULT 0,
          duration_minutes_rounded INTEGER DEFAULT 0,
          FOREIGN KEY (task_id) REFERENCES tasks(id)
        )
      ''');
      // Migrate existing task start/end into task_sessions
      final tasks = await db.query('tasks');
      for (final task in tasks) {
        if (task['start_time'] != null) {
          int raw = 0;
          int rounded = 0;
          if (task['end_time'] != null) {
            final start =
                DateTime.parse(task['start_time'] as String);
            final end =
                DateTime.parse(task['end_time'] as String);
            raw = end.difference(start).inMinutes;
            rounded = ((raw / 15).round() * 15);
          }
          await db.insert('task_sessions', {
            'task_id': task['id'],
            'start_time': task['start_time'],
            'start_photo': task['start_photo'],
            'end_time': task['end_time'],
            'end_photo': task['end_photo'],
            'duration_minutes_raw': raw,
            'duration_minutes_rounded': rounded,
          });
        }
      }
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
        FOREIGN KEY (work_day_id)
          REFERENCES work_days(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        work_day_id INTEGER NOT NULL,
        name TEXT DEFAULT 'Unnamed Task',
        division TEXT,
        notes TEXT,
        start_time TEXT NOT NULL,
        start_location TEXT,
        hourly_rate REAL DEFAULT 0.0,
        FOREIGN KEY (work_day_id)
          REFERENCES work_days(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE task_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        start_photo TEXT,
        end_time TEXT,
        end_photo TEXT,
        duration_minutes_raw INTEGER DEFAULT 0,
        duration_minutes_rounded INTEGER DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE task_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        photo_path TEXT NOT NULL,
        photo_type TEXT DEFAULT 'general',
        created_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks(id)
      )
    ''');
  }

  /// Cascade delete a work day and everything under it
  Future<void> deleteDayCascade(int workDayId) async {
    final db = await instance.database;

    final taskMaps = await db.query('tasks',
        columns: ['id'],
        where: 'work_day_id = ?',
        whereArgs: [workDayId]);

    for (final task in taskMaps) {
      await db.delete('task_sessions',
          where: 'task_id = ?',
          whereArgs: [task['id']]);
      await db.delete('task_photos',
          where: 'task_id = ?',
          whereArgs: [task['id']]);
    }

    await db.delete('tasks',
        where: 'work_day_id = ?',
        whereArgs: [workDayId]);
    await db.delete('sessions',
        where: 'work_day_id = ?',
        whereArgs: [workDayId]);
    await db.delete('work_days',
        where: 'id = ?', whereArgs: [workDayId]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}