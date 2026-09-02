import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';

class BatchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<int> insertBatch(Batch batch) async {
    final db = await _dbHelper.database;
    final id = await db.insert('batches', batch.toMap());
    final createdBatch = batch.copyWith(id: id);
    await CloudSyncService.instance.pushBatch(createdBatch);
    CloudSyncService.instance.notifyDataChanged('batches');
    return id;
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  Future<List<Batch>> getAllBatches() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('batches');
    return List.generate(maps.length, (i) => Batch.fromMap(maps[i]));
  }

  Future<Batch?> getBatchById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return Batch.fromMap(maps.first);
    return null;
  }

  /// Returns batches where batches.teacher_id = [teacherId].
  /// Fallbacks to all batches if no specific teacher batches found.
  Future<List<Batch>> fetchTeacherBatches(int teacherId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    if (maps.isNotEmpty) {
      return List.generate(maps.length, (i) => Batch.fromMap(maps[i]));
    }
    return getAllBatches();
  }

  /// Alias kept for backwards compatibility.
  Future<List<Batch>> getBatchesByTeacher(int teacherId) =>
      fetchTeacherBatches(teacherId);

  /// Returns all [Student]s enrolled in a batch (via students.batch_id).
  Future<List<Student>> getStudentsForBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.id
      WHERE (s.is_deleted IS NULL OR s.is_deleted = 0)
        AND (
          s.batch_id = ?
          OR LOWER(b.name) = (SELECT LOWER(name) FROM batches WHERE id = ?)
        )
      ORDER BY s.name ASC
    ''', [batchId, batchId]);

    if (maps.isNotEmpty) {
      return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
    }

    final List<Map<String, dynamic>> fallbackMaps = await db.query(
      'students',
      where: 'is_deleted IS NULL OR is_deleted = 0',
      orderBy: 'name ASC',
    );
    return List.generate(fallbackMaps.length, (i) => Student.fromMap(fallbackMaps[i]));
  }

  // ── Assign / Revoke ──────────────────────────────────────────────────────────

  /// Assigns a teacher to a batch. Passing [teacherId] sets batches.teacher_id.
  Future<void> assignTeacherToBatch(int batchId, int teacherId) async {
    final db = await _dbHelper.database;
    await db.update(
      'batches',
      {'teacher_id': teacherId},
      where: 'id = ?',
      whereArgs: [batchId],
    );
    final batch = await getBatchById(batchId);
    if (batch != null) {
      await CloudSyncService.instance.pushBatch(batch);
    }
    CloudSyncService.instance.notifyDataChanged('batches');
  }

  /// Removes any teacher assignment from a batch (sets teacher_id to NULL).
  Future<void> removeTeacherFromBatch(int batchId) async {
    final db = await _dbHelper.database;
    await db.update(
      'batches',
      {'teacher_id': null},
      where: 'id = ?',
      whereArgs: [batchId],
    );
    final batch = await getBatchById(batchId);
    if (batch != null) {
      await CloudSyncService.instance.pushBatch(batch);
    }
    CloudSyncService.instance.notifyDataChanged('batches');
  }

  // ── Update / Delete ──────────────────────────────────────────────────────────

  Future<int> updateBatch(Batch batch) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
    await CloudSyncService.instance.pushBatch(batch);
    CloudSyncService.instance.notifyDataChanged('batches');
    return res;
  }

  Future<int> deleteBatch(int id) async {
    final db = await _dbHelper.database;
    final res = await db.delete(
      'batches',
      where: 'id = ?',
      whereArgs: [id],
    );
    await CloudSyncService.instance.deleteBatchCloud(id);
    CloudSyncService.instance.notifyDataChanged('batches');
    return res;
  }
}
