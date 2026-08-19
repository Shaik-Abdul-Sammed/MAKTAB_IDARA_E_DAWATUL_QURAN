import 'package:maktab_app/services/database_helper.dart';
import '../models/audit_log.dart';

class AuditRepository {
  static const String tableName = 'audit_logs';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        performed_by TEXT
      )
    ''');
  }

  Future<int> insert(AuditLog log) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert(tableName, log.toMap());
  }

  Future<List<AuditLog>> getAllLogs() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('audit_logs', orderBy: 'timestamp DESC');
    return maps.map((e) => AuditLog.fromMap(e)).toList();
  }

  Future<List<AuditLog>> getLogs({int limit = 100, int offset = 0}) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(tableName, orderBy: 'timestamp DESC', limit: limit, offset: offset);
    return List.generate(maps.length, (i) => AuditLog.fromMap(maps[i]));
  }
}