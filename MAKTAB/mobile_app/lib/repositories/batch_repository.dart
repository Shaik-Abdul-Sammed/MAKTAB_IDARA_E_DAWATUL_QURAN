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
    return id;
  }

  // ── Read ─────────────────────────────────────────────────────────────────────

  Future<List<Batch>> getAllBatches() async {
    final db = await _dbHelper.database;
    // Trigger background pull for latest updates
    final maktabId = await CloudSyncService.instance.getMaktabId();
    CloudSyncService.instance.pullAllDataForMaktab(maktabId).catchError((_) => false);

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
  /// Used by the teacher-side screens to scope data.
  Future<List<Batch>> fetchTeacherBatches(int teacherId) async {
    final db = await _dbHelper.database;
    // Trigger pull so teacher device gets assigned batches
    final maktabId = await CloudSyncService.instance.getMaktabId();
    await CloudSyncService.instance.pullAllDataForMaktab(maktabId);

    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    return List.generate(maps.length, (i) => Batch.fromMap(maps[i]));
  }

  /// Alias kept for backwards compatibility.
  Future<List<Batch>> getBatchesByTeacher(int teacherId) =>
      fetchTeacherBatches(teacherId);

  /// Returns all [Student]s enrolled in a batch (via students.batch_id).
  Future<List<Student>> getStudentsForBatch(int batchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'batch_id = ? AND (is_deleted IS NULL OR is_deleted = 0)',
      whereArgs: [batchId],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
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
    return res;
  }
}
