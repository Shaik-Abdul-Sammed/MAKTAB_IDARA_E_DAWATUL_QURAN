import 'package:flutter/foundation.dart';
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
    CloudSyncService.instance.notifyDataChanged('attendance');
    return id;
  }

  Future<void> insertAttendances(List<Attendance> attendances) async {
    final db = await _dbHelper.database;
    final List<Attendance> createdList = [];
    await db.transaction((txn) async {
      for (var att in attendances) {
        final insertedId = await txn.insert('attendance', att.toMap());
        createdList.add(att.copyWith(id: insertedId));
      }
    });
    for (var created in createdList) {
      try {
        await CloudSyncService.instance.pushAttendance(created);
      } catch (e) {
        debugPrint('CloudSync push error for attendance ${created.id}: $e');
      }
    }
    CloudSyncService.instance.notifyDataChanged('attendance');
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
      }
    });
    for (var att in attendances) {
      try {
        await CloudSyncService.instance.pushAttendance(att);
      } catch (e) {
        debugPrint('CloudSync push error for attendance ${att.id}: $e');
      }
    }
    CloudSyncService.instance.notifyDataChanged('attendance');
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
      WHERE substr(a.date, 1, 10) = substr(?, 1, 10) AND s.batch_id = ?
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
        COUNT(DISTINCT CASE WHEN a.status = 'Present' THEN s.id END) as present,
        COUNT(DISTINCT CASE WHEN a.status IS NOT NULL AND a.status != 'Present' THEN s.id END) as absent,
        COUNT(DISTINCT CASE WHEN a.status IS NOT NULL THEN s.id END) as marked
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.id
      LEFT JOIN attendance a ON a.student_id = s.id AND substr(a.date, 1, 10) = substr(?, 1, 10)
      WHERE (s.is_deleted IS NULL OR s.is_deleted = 0)
        AND (
          s.batch_id = ?
          OR LOWER(b.name) = (SELECT LOWER(name) FROM batches WHERE id = ?)
        )
    ''', [date, batchId, batchId]);

    int total = 0, present = 0, absent = 0, marked = 0;
    if (rows.isNotEmpty) {
      final row = rows.first;
      total = (row['total'] as int?) ?? 0;
      present = (row['present'] as int?) ?? 0;
      absent = (row['absent'] as int?) ?? 0;
      marked = (row['marked'] as int?) ?? (present + absent);
    }

    // Fail-safe fallback: If specific batch count is 0, count all active students in the Maktab
    if (total == 0) {
      final allRows = await db.rawQuery('''
        SELECT
          COUNT(DISTINCT s.id) as total,
          COUNT(DISTINCT CASE WHEN a.status = 'Present' THEN s.id END) as present,
          COUNT(DISTINCT CASE WHEN a.status IS NOT NULL AND a.status != 'Present' THEN s.id END) as absent,
          COUNT(DISTINCT CASE WHEN a.status IS NOT NULL THEN s.id END) as marked
        FROM students s
        LEFT JOIN attendance a ON a.student_id = s.id AND substr(a.date, 1, 10) = substr(?, 1, 10)
        WHERE (s.is_deleted IS NULL OR s.is_deleted = 0)
      ''', [date]);
      if (allRows.isNotEmpty) {
        final row = allRows.first;
        total = (row['total'] as int?) ?? 0;
        present = (row['present'] as int?) ?? 0;
        absent = (row['absent'] as int?) ?? 0;
        marked = (row['marked'] as int?) ?? (present + absent);
      }
    }

    return {'total': total, 'present': present, 'absent': absent, 'marked': marked};
  }
}
