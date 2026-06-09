import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/worker.dart';

class WorkerDao {
  Future<int> insert(Worker worker) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('workers', worker.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Worker?> getFirst() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('workers', limit: 1);
    if (maps.isEmpty) return null;
    return Worker.fromMap(maps.first);
  }

  Future<int> update(Worker worker) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('workers', worker.toMap(),
        where: 'id = ?', whereArgs: [worker.id]);
  }
}