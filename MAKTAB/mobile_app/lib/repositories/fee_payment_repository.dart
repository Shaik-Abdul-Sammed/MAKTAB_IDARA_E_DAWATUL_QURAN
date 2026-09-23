import '../models/fee_payment.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';

class FeePaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertFeePayment(FeePayment payment) async {
    final db = await _dbHelper.database;
    // Insert with is_synced = 0 (model default). This ensures offline records
    // are picked up by the retry queue.
    final id = await db.insert('fee_payments', payment.toMap());
    try {
      final created = payment.copyWith(id: id);
      await CloudSyncService.instance.pushFeePayment(created);
      // Mark as synced only after successful push.
      await db.update(
        'fee_payments',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {
      // Push failed (likely offline). Record stays is_synced = 0 so the
      // retry queue (cloud_sync_service getPaymentsForStudent / syncNow) can
      // re-push it later.
    }
    return id;
  }

  Future<List<FeePayment>> getPaymentsForStudent(int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fee_payments',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((e) => FeePayment.fromMap(e)).toList();
  }

  Future<int> deleteFeePayment(int id) async {
    final db = await _dbHelper.database;
    final res = await db.delete(
      'fee_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
    await CloudSyncService.instance.deleteFeePaymentCloud(id);
    return res;
  }

  Future<int> updateFeePayment(FeePayment payment) async {
    final db = await _dbHelper.database;
    final res = await db.update(
      'fee_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
    await CloudSyncService.instance.pushFeePayment(payment);
    return res;
  }

  Future<List<FeePayment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final maps = await db.query('fee_payments', orderBy: 'timestamp DESC');
    return maps.map((e) => FeePayment.fromMap(e)).toList();
  }

  /// Retry-sync all unsynced payments. Called by CloudSyncService.syncNow.
  Future<void> retryUnsyncedPayments() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fee_payments',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    for (final row in maps) {
      final payment = FeePayment.fromMap(row);
      try {
        await CloudSyncService.instance.pushFeePayment(payment);
        await db.update(
          'fee_payments',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [payment.id],
        );
      } catch (_) {
        // Still offline — leave is_synced = 0.
      }
    }
  }

  Future<void> markReceiptSent(int id, {DateTime? sentAt}) async {
    final db = await _dbHelper.database;
    await db.update(
      'fee_payments',
      {
        'receipt_sent': 1,
        'receipt_sent_at': (sentAt ?? DateTime.now()).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<FeePayment>> getUnsentReceipts({int? studentId}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'fee_payments',
      where: studentId != null
          ? 'receipt_sent = 0 AND student_id = ?'
          : 'receipt_sent = 0',
      whereArgs: studentId != null ? [studentId] : null,
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => FeePayment.fromMap(m)).toList();
  }

  /// Returns all fee payments for students whose batch is assigned to the given
  /// canonical teacherId. Sorted by timestamp descending.
  Future<List<Map<String, dynamic>>> getPaymentsByTeacherBatches(int canonicalTeacherId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT fp.*, s.name AS student_name, s.admission_number AS student_admission,
             s.phone AS student_phone, s.preferred_language AS student_lang
      FROM fee_payments fp
      INNER JOIN students s ON fp.student_id = s.id
      INNER JOIN batches b ON s.batch_id = b.id
      WHERE b.teacher_id = ?
        AND (s.is_deleted IS NULL OR s.is_deleted = 0)
      ORDER BY fp.timestamp DESC
    ''', [canonicalTeacherId]);
    return rows;
  }

  /// Returns aggregate fee totals for a teacher's batches within an optional
  /// date range. Both [fromDate] and [toDate] are inclusive yyyy-MM-dd strings.
  Future<Map<String, dynamic>> getTeacherTotals({
    required int canonicalTeacherId,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>['b.teacher_id = ?'];
    final args = <Object?>[canonicalTeacherId];
    if (fromDate != null) {
      where.add("substr(fp.timestamp, 1, 10) >= ?");
      args.add(fromDate);
    }
    if (toDate != null) {
      where.add("substr(fp.timestamp, 1, 10) <= ?");
      args.add(toDate);
    }
    final whereSql = where.join(' AND ');

    final summary = await db.rawQuery('''
      SELECT
        COALESCE(SUM(fp.amount), 0) AS total,
        COUNT(fp.id) AS count
      FROM fee_payments fp
      INNER JOIN students s ON fp.student_id = s.id
      INNER JOIN batches b ON s.batch_id = b.id
      WHERE $whereSql
    ''', args);

    final byMode = await db.rawQuery('''
      SELECT fp.mode, COALESCE(SUM(fp.amount), 0) AS total
      FROM fee_payments fp
      INNER JOIN students s ON fp.student_id = s.id
      INNER JOIN batches b ON s.batch_id = b.id
      WHERE $whereSql
      GROUP BY fp.mode
    ''', args);

    return {
      'total': (summary.first['total'] as num?)?.toInt() ?? 0,
      'count': (summary.first['count'] as num?)?.toInt() ?? 0,
      'byMode': {
        for (final r in byMode)
          (r['mode'] as String? ?? 'Unknown'): ((r['total'] as num?)?.toInt() ?? 0),
      },
    };
  }
}
