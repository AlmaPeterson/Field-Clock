import '../database_helper.dart';
import '../../models/task_photo.dart';

class TaskPhotoDao {
  Future<int> insert(TaskPhoto photo) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('task_photos', photo.toMap());
  }

  Future<List<TaskPhoto>> getByTask(int taskId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'task_photos',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => TaskPhoto.fromMap(m)).toList();
  }

  Future<int> update(TaskPhoto photo) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'task_photos',
      photo.toMap(),
      where: 'id = ?',
      whereArgs: [photo.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'task_photos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByTask(int taskId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'task_photos',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }
}