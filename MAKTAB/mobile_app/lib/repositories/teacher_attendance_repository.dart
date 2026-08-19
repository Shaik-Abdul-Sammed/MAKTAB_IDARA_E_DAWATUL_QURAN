import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class TeacherAttendanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Write ────────────────────────────────────────────────────────────────────

  Future<int> insertAttendance(TeacherAttendance attendance) async {
    final db = await _dbHelper.database;
    final id = await db.insert('teacher_attendance', attendance.toMap());
    final created = attendance.copyWith(id: id);
    await CloudSyncService.instance.pushTeacherAttendance(created);
    return id;
  }

  /// Insert or update — prevents duplicate records for the same teacher+date.
  Future<void> upsertAttendance(TeacherAttendance attendance) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> existing = await db.query(
      'teacher_attendance',
      where: 'teacher_id = ? AND date = ?',
      whereArgs: [attendance.teacherId, attendance.date],
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final updated = attendance.copyWith(id: id);
      await db.update(
        'teacher_attendance',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await CloudSyncService.instance.pushTeacherAttendance(updated);
    } else {
      final id = await db.insert('teacher_attendance', attendance.toMap());
      final created = attendance.copyWith(id: id);
      await CloudSyncService.instance.pushTeacherAttendance(created);
    }
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  Future<List<TeacherAttendance>> getAllRecords() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('teacher_attendance');
    return maps.map((e) => TeacherAttendance.fromMap(e)).toList();
  }

  Future<List<TeacherAttendance>> getAttendanceByDate(String date) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teacher_attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => TeacherAttendance.fromMap(maps[i]));
  }

  Future<List<TeacherAttendance>> getAttendanceByTeacher(
    int teacherId, {
    String? from,
    String? to,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = 'teacher_id = ?';
    List<dynamic> whereArgs = [teacherId];
    if (from != null && to != null) {
      whereClause += ' AND date BETWEEN ? AND ?';
      whereArgs.addAll([from, to]);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'teacher_attendance',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => TeacherAttendance.fromMap(maps[i]));
  }

  /// Returns a summary map: {present, absent, late, leave, total} for a
  /// specific teacher and month (e.g. yearMonth = '2026-08').
  Future<Map<String, int>> getMonthSummary(
      int teacherId, String yearMonth) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT status, COUNT(*) as cnt
      FROM teacher_attendance
      WHERE teacher_id = ? AND date LIKE ?
      GROUP BY status
    ''', [teacherId, '$yearMonth%']);

    int present = 0, absent = 0, late = 0, leave = 0;
    for (final row in rows) {
      final status = (row['status'] as String).toLowerCase();
      final cnt = row['cnt'] as int;
      if (status == 'present') present = cnt;
      if (status == 'absent') absent = cnt;
      if (status == 'late') late = cnt;
      if (status == 'leave') leave = cnt;
    }
    return {
      'present': present,
      'absent': absent,
      'late': late,
      'leave': leave,
      'total': present + absent + late + leave,
    };
  }

  /// Used by admin to see all teachers on a given date with their names.
  Future<List<Map<String, dynamic>>> getTeacherAttendanceSummary(
      String date) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT ta.*, u.name as teacher_name
      FROM teacher_attendance ta
      INNER JOIN users u ON ta.teacher_id = u.id
      WHERE ta.date = ?
    ''', [date]);
  }
}
