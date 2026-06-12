import '../database_helper.dart';
import '../../models/session.dart';

class SessionDao {
  Future<int> insert(Session session) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('sessions', session.toMap());
  }

  Future<List<Session>> getByWorkDay(int workDayId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'sessions',
      where: 'work_day_id = ?',
      whereArgs: [workDayId],
      orderBy: 'clock_in_time ASC',
    );
    return maps.map((m) => Session.fromMap(m)).toList();
  }

  Future<Session?> getActiveSession(int workDayId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'sessions',
      where: 'work_day_id = ? AND clock_out_time IS NULL',
      whereArgs: [workDayId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<int> update(Session session) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteByWorkDay(int workDayId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'sessions',
      where: 'work_day_id = ?',
      whereArgs: [workDayId],
    );
  }
}