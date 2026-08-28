import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class StudentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<int> insertStudent(Student student) async {
    final db = await _dbHelper.database;
    final map = student.toMap();
    map['batch_id'] ??= 1;
    final id = await db.insert('students', map);
    final createdStudent = student.copyWith(id: id, batchId: map['batch_id'] as int);
    await CloudSyncService.instance.pushStudent(createdStudent);
    CloudSyncService.instance.notifyDataChanged('students');
    return id;
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  Future<List<Student>> getAllStudents() async {
    final db = await _dbHelper.database;
    // Trigger background pull for latest updates
    final maktabId = await CloudSyncService.instance.getMaktabId();
    CloudSyncService.instance.pullAllDataForMaktab(maktabId).catchError((_) => false);

    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'is_deleted IS NULL OR is_deleted = 0',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  Future<Student?> getStudentById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Student.fromMap(maps.first);
    return null;
  }

  Future<List<Student>> getStudentsByBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'batch_id = ? AND (is_deleted IS NULL OR is_deleted = 0)',
      whereArgs: [batchId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Returns all students in batches assigned to [teacherId].
  /// Uses a JOIN so only active students in the teacher's own batches are visible.
  Future<List<Student>> getStudentsByTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*
      FROM students s
      INNER JOIN batches b ON s.batch_id = b.id
      WHERE b.teacher_id = ? AND (s.is_deleted IS NULL OR s.is_deleted = 0)
      ORDER BY s.name ASC
    ''', [teacherId]);
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // ── Past / Deleted Students ──────────────────────────────────────────────────

  /// Fetches all soft-deleted / past students for Admin view.
  Future<List<Student>> getDeletedStudents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC, name ASC',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  /// Restores a soft-deleted student back to active state.
  Future<int> restoreStudent(int id) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'students',
      {'is_deleted': 0, 'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    final student = await getStudentById(id);
    if (student != null) {
      await CloudSyncService.instance.pushStudent(student);
    }
    return res;
  }

  // ── Notes ────────────────────────────────────────────────────────────────────

  /// Saves a teacher's private note for a student.
  Future<void> saveTeacherNote(int studentId, String note) async {
    final db = await _dbHelper.database;
    await db.update(
      'students',
      {'teacher_notes': note},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    final student = await getStudentById(studentId);
    if (student != null) {
      await CloudSyncService.instance.pushStudent(student);
    }
  }

  // ── Update / Delete ──────────────────────────────────────────────────────────

  Future<int> updateStudent(Student student) async {
    final db = await _dbHelper.database;
    final map = student.toMap();
    map['batch_id'] ??= 1;
    final res = await db.update(
      'students',
      map,
      where: 'id = ?',
      whereArgs: [student.id],
    );
    await CloudSyncService.instance.pushStudent(student.copyWith(batchId: map['batch_id'] as int));
    CloudSyncService.instance.notifyDataChanged('students');
    return res;
  }

  /// Soft deletes a student by setting is_deleted = 1 and deleted_at timestamp.
  Future<int> deleteStudent(int id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final res = await db.update(
      'students',
      {'is_deleted': 1, 'deleted_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    final student = await getStudentById(id);
    if (student != null) {
      await CloudSyncService.instance.pushStudent(student);
    }
    CloudSyncService.instance.notifyDataChanged('students');
    return res;
  }

  /// Permanently removes a student and their data from DB.
  Future<int> permanentlyDeleteStudent(int id) async {
    final db = await _dbHelper.database;
    final res = await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    await CloudSyncService.instance.deleteStudentCloud(id);
    CloudSyncService.instance.notifyDataChanged('students');
    return res;
  }
}
