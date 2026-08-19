import 'package:maktab_app/models/quran_progress.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class QuranProgressRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Write ────────────────────────────────────────────────────────────────────

  Future<int> insertQuranProgress(QuranProgress progress) async {
    final db = await _dbHelper.database;
    final id = await db.insert('quran_progress', progress.toMap());
    final created = progress.copyWith(id: id);
    await CloudSyncService.instance.pushQuranProgress(created);
    return id;
  }

  Future<int> updateQuranProgress(QuranProgress progress) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'quran_progress',
      progress.toMap(),
      where: 'id = ?',
      whereArgs: [progress.id],
    );
    await CloudSyncService.instance.pushQuranProgress(progress);
    return res;
  }

  // ── Read by Student ──────────────────────────────────────────────────────────

  Future<List<QuranProgress>> getAllProgress() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('quran_progress');
    return maps.map((e) => QuranProgress.fromMap(e)).toList();
  }

  Future<List<QuranProgress>> getProgressByStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quran_progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => QuranProgress.fromMap(maps[i]));
  }

  // ── Teacher-Scoped Reads ─────────────────────────────────────────────────────

  /// Returns all QuranProgress entries for students in batches assigned to
  /// [teacherId]. Used by admin to see what a teacher has logged.
  Future<List<QuranProgress>> getProgressByTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT qp.*
      FROM quran_progress qp
      INNER JOIN students s ON qp.student_id = s.id
      INNER JOIN batches b ON s.batch_id = b.id
      WHERE b.teacher_id = ?
      ORDER BY qp.date DESC
    ''', [teacherId]);
    return List.generate(maps.length, (i) => QuranProgress.fromMap(maps[i]));
  }

  // ── Batch Overview ───────────────────────────────────────────────────────────

  /// Returns the most recent QuranProgress entry for EACH student in [batchId].
  /// Used on the Admin's BatchDetailsScreen to show "Class Progress Overview".
  Future<List<Map<String, dynamic>>> getLatestProgressForBatch(
      int batchId) async {
    final db = await _dbHelper.database;
    // For each student in the batch, get their most recent progress row.
    return await db.rawQuery('''
      SELECT s.id as student_id, s.name as student_name,
             qp.date, qp.surah, qp.ayah_from, qp.ayah_to, qp.grade, qp.remarks
      FROM students s
      LEFT JOIN quran_progress qp ON qp.id = (
        SELECT id FROM quran_progress
        WHERE student_id = s.id
        ORDER BY date DESC
        LIMIT 1
      )
      WHERE s.batch_id = ?
      ORDER BY s.name ASC
    ''', [batchId]);
  }

  /// Total count of progress entries submitted by a teacher this month.
  Future<int> getMonthlyProgressCount(
      int teacherId, String yearMonth) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as cnt
      FROM quran_progress qp
      INNER JOIN students s ON qp.student_id = s.id
      INNER JOIN batches b ON s.batch_id = b.id
      WHERE b.teacher_id = ? AND qp.date LIKE ?
    ''', [teacherId, '$yearMonth%']);
    return (rows.first['cnt'] as int?) ?? 0;
  }
}
