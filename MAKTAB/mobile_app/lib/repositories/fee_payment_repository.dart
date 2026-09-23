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
}
