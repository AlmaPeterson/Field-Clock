import '../database_helper.dart';
import '../../models/work_day.dart';

class WorkDayDao {
  Future<int> insert(WorkDay day) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('work_days', day.toMap());
  }

  Future<WorkDay?> getToday() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now();
    final dateStr = today.toIso8601String().substring(0, 10);
    final maps = await db.query('work_days',
        where: "date LIKE ?", whereArgs: ['$dateStr%'], limit: 1);
    if (maps.isEmpty) return null;
    return WorkDay.fromMap(maps.first);
  }

  Future<WorkDay?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps =
        await db.query('work_days', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WorkDay.fromMap(maps.first);
  }

  Future<List<WorkDay>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('work_days', orderBy: 'date DESC');
    return maps.map((m) => WorkDay.fromMap(m)).toList();
  }

  Future<List<WorkDay>> getByJob(int jobId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('work_days',
        where: 'job_id = ?', whereArgs: [jobId], orderBy: 'date DESC');
    return maps.map((m) => WorkDay.fromMap(m)).toList();
  }

  Future<int> update(WorkDay day) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('work_days', day.toMap(),
        where: 'id = ?', whereArgs: [day.id]);
  }
}