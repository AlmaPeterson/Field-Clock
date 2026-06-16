import '../database_helper.dart';
import '../../models/task_session.dart';

class TaskSessionDao {
  Future<int> insert(TaskSession session) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert(
        'task_sessions', session.toMap());
  }

  Future<List<TaskSession>> getByTask(
      int taskId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'task_sessions',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'start_time ASC',
    );
    return maps
        .map((m) => TaskSession.fromMap(m))
        .toList();
  }

  Future<TaskSession?> getActiveSession(
      int taskId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'task_sessions',
      where: 'task_id = ? AND end_time IS NULL',
      whereArgs: [taskId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskSession.fromMap(maps.first);
  }

  Future<int> update(TaskSession session) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'task_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'task_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByTask(int taskId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'task_sessions',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  /// Total rounded minutes across all completed
  /// sessions for a task
  Future<int> totalMinutes(int taskId) async {
    final sessions = await getByTask(taskId);
    return sessions
        .where((s) => !s.isActive)
        .fold<int>(0,
            (sum, s) => sum + s.durationMinutesRounded);
  }
}