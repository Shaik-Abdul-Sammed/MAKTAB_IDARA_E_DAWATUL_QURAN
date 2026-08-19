import '../models/behavior_log.dart';
import '../services/database_helper.dart';

class BehaviorRepository {
  Future<List<BehaviorLog>> getAllLogs() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('behavior_logs');
    return maps.map((e) => BehaviorLog.fromMap(e)).toList();
  }

  Future<int> insertLog(BehaviorLog item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('behavior_logs', item.toMap());
  }
  Future<int> updateLog(BehaviorLog item) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update('behavior_logs', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }
  Future<int> deleteLog(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('behavior_logs', where: 'id = ?', whereArgs: [id]);
  }

}