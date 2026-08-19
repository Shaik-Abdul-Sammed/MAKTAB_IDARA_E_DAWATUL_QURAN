import 'dart:convert';
import 'package:maktab_app/services/database_helper.dart';
import 'queue_item.dart';

class QueueManager {
  static const String tableName = 'offline_queue';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  static Future<int> enqueue(String action, Map<String, dynamic> payload) async {
    final db = await DatabaseHelper.instance.database;
    final item = QueueItem(
      action: action,
      payload: jsonEncode(payload),
      createdAt: DateTime.now().toIso8601String(),
    );
    return await db.insert(tableName, item.toMap());
  }

  static Future<List<QueueItem>> getPendingItems() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(tableName, where: 'status = ?', whereArgs: ['PENDING']);
    return List.generate(maps.length, (i) => QueueItem.fromMap(maps[i]));
  }

  static Future<void> markCompleted(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(tableName, {'status': 'COMPLETED'}, where: 'id = ?', whereArgs: [id]);
  }
}