import '../database_helper.dart';
import '../../models/job.dart';

class JobDao {
  Future<int> insert(Job job) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('jobs', job.toMap());
  }

  Future<List<Job>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('jobs', orderBy: 'start_date DESC');
    return maps.map((m) => Job.fromMap(m)).toList();
  }

  Future<List<Job>> getActive() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('jobs',
        where: 'status = ?', whereArgs: ['active'],
        orderBy: 'start_date DESC');
    return maps.map((m) => Job.fromMap(m)).toList();
  }

  Future<Job?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('jobs', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Job.fromMap(maps.first);
  }

  Future<int> update(Job job) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('jobs', job.toMap(),
        where: 'id = ?', whereArgs: [job.id]);
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('jobs', where: 'id = ?', whereArgs: [id]);
  }
}