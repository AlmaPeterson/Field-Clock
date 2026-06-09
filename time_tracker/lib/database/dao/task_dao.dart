import '../database_helper.dart';
import '../../models/task.dart';

class TaskDao {
  Future<int> insert(Task task) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getByWorkDay(int workDayId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('tasks',
        where: 'work_day_id = ?',
        whereArgs: [workDayId],
        orderBy: 'start_time ASC');
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<Task?> getActiveTask(int workDayId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('tasks',
        where: 'work_day_id = ? AND end_time IS NULL',
        whereArgs: [workDayId],
        limit: 1);
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<Task?> getById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<int> update(Task task) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}