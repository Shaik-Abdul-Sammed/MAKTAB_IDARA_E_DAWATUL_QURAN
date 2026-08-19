import '../models/fee_payment.dart';
import '../services/database_helper.dart';
import '../services/cloud_sync_service.dart';

class FeePaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertFeePayment(FeePayment payment) async {
    final db = await _dbHelper.database;
    final id = await db.insert('fee_payments', payment.toMap());
    final created = payment.copyWith(id: id);
    await CloudSyncService.instance.pushFeePayment(created);
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
    return await db.delete(
      'fee_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateFeePayment(FeePayment payment) async {
    final db = await _dbHelper.database;
    return await db.update(
      'fee_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<List<FeePayment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final maps = await db.query('fee_payments', orderBy: 'timestamp DESC');
    return maps.map((e) => FeePayment.fromMap(e)).toList();
  }
}
