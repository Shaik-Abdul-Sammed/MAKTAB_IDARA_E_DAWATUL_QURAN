import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class AttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertAttendance(Attendance attendance) async {
    final db = await _dbHelper.database;
    final id = await db.insert('attendance', attendance.toMap());
    final createdAtt = attendance.copyWith(id: id);
    await CloudSyncService.instance.pushAttendance(createdAtt);
    return id;
  }

  Future<void> insertAttendances(List<Attendance> attendances) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var att in attendances) {
        await txn.insert('attendance', att.toMap());
        await CloudSyncService.instance.pushAttendance(att);
      }
    });
  }

  Future<void> updateAttendances(List<Attendance> attendances) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (var att in attendances) {
        await txn.update(
          'attendance',
          att.toMap(),
          where: 'id = ?',
          whereArgs: [att.id],
        );
        await CloudSyncService.instance.pushAttendance(att);
      }
    });
  }

    Future<List<Attendance>> getAttendanceForBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.* FROM attendance a
      INNER JOIN students s ON a.student_id = s.id
      WHERE s.batch_id = ?
    ''', [batchId]);
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<List<Attendance>> getAllAttendance() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('attendance');
    return maps.map((e) => Attendance.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentStudentAttendance({int limit = 5}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.date, a.status, s.name as student_name, b.name as batch_name
      FROM attendance a
      INNER JOIN students s ON a.student_id = s.id
      INNER JOIN batches b ON s.batch_id = b.id
      ORDER BY a.id DESC
      LIMIT ?
    ''', [limit]);
    return maps;
  }

  Future<List<Attendance>> getAttendanceByDateAndBatch(String date, int batchId) async {
    final db = await _dbHelper.database;
    // We need to join with students to filter by batch
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT a.* FROM attendance a
      INNER JOIN students s ON a.student_id = s.id
      WHERE a.date = ? AND s.batch_id = ?
    ''', [date, batchId]);
    
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  Future<int> updateAttendance(Attendance attendance) async {
    final db = await _dbHelper.database;
    return await db.update(
      'attendance',
      attendance.toMap(),
      where: 'id = ?',
      whereArgs: [attendance.id],
    );
  }

  // Method to check if attendance for a batch on a date already exists
  Future<bool> hasAttendanceForBatch(String date, int batchId) async {
    final records = await getAttendanceByDateAndBatch(date, batchId);
    return records.isNotEmpty;
  }

  Future<List<Attendance>> getAttendanceByStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  /// Returns a map with present/absent/total counts for a batch on a date.
  Future<Map<String, int>> getAttendanceCountsForBatchDate(String date, int batchId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT s.id) as total,
        SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN a.status != 'Present' THEN 1 ELSE 0 END) as absent
      FROM students s
      LEFT JOIN attendance a ON a.student_id = s.id AND a.date = ?
      WHERE s.batch_id = ?
    ''', [date, batchId]);
    if (rows.isEmpty) return {'total': 0, 'present': 0, 'absent': 0, 'marked': 0};
    final row = rows.first;
    final total = (row['total'] as int?) ?? 0;
    final present = (row['present'] as int?) ?? 0;
    final absent = (row['absent'] as int?) ?? 0;
    final marked = present + absent;
    return {'total': total, 'present': present, 'absent': absent, 'marked': marked};
  }
}
