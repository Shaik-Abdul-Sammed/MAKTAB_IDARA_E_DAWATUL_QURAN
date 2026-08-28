import 'package:maktab_app/models/salary_payment.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/utils/offline/queue_manager.dart';

class SalaryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new salary payment record
  Future<int> insertPayment(SalaryPayment payment) async {
    final db = await _dbHelper.database;
    final map = payment.toMap();
    map.remove('id'); // SQLite auto-increments
    final id = await db.insert('salary_payments', map);
    final created = payment.copyWith(id: id);

    try {
      await CloudSyncService.instance.pushSalaryPayment(created);
      await QueueManager.enqueue('CREATE_SALARY_PAYMENT', {
        ...created.toMap(),
        'id': id,
      });
    } catch (_) {}

    return id;
  }

  /// Update an existing salary payment record
  Future<int> updatePayment(SalaryPayment payment) async {
    if (payment.id == null) return 0;
    final db = await _dbHelper.database;
    final count = await db.update(
      'salary_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );

    try {
      await CloudSyncService.instance.pushSalaryPayment(payment);
      await QueueManager.enqueue('UPDATE_SALARY_PAYMENT', payment.toMap());
    } catch (_) {}

    return count;
  }

  /// Delete a salary payment record
  Future<int> deletePayment(int id) async {
    final db = await _dbHelper.database;
    final count = await db.delete(
      'salary_payments',
      where: 'id = ?',
      whereArgs: [id],
    );

    try {
      await CloudSyncService.instance.deleteSalaryPaymentCloud(id);
      await QueueManager.enqueue('DELETE_SALARY_PAYMENT', {'id': id});
    } catch (_) {}

    return count;
  }

  /// Get all payments for a specific teacher
  Future<List<SalaryPayment>> getPaymentsForTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'salary_payments',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'payment_date DESC, id DESC',
    );
    return maps.map((map) => SalaryPayment.fromMap(map)).toList();
  }

  /// Get all payments for a teacher in a specific month (e.g. "2026-08")
  Future<List<SalaryPayment>> getPaymentsForTeacherAndMonth(int teacherId, String salaryMonth) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'salary_payments',
      where: 'teacher_id = ? AND salary_month = ?',
      whereArgs: [teacherId, salaryMonth],
      orderBy: 'payment_date DESC',
    );
    return maps.map((map) => SalaryPayment.fromMap(map)).toList();
  }

  /// Get total amount paid to a teacher for a specific month
  Future<int> getTotalPaidForTeacherAndMonth(int teacherId, String salaryMonth) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM salary_payments WHERE teacher_id = ? AND salary_month = ?',
      [teacherId, salaryMonth],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toInt();
    }
    return 0;
  }

  /// Get all salary payments for a given month across all teachers in a maktab
  Future<List<SalaryPayment>> getPaymentsForMonth(String maktabId, String salaryMonth) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'salary_payments',
      where: 'maktab_id = ? AND salary_month = ?',
      whereArgs: [maktabId, salaryMonth],
      orderBy: 'payment_date DESC',
    );
    return maps.map((map) => SalaryPayment.fromMap(map)).toList();
  }

  /// Get all salary payments for a maktab
  Future<List<SalaryPayment>> getAllPayments(String maktabId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'salary_payments',
      where: 'maktab_id = ?',
      whereArgs: [maktabId],
      orderBy: 'payment_date DESC',
    );
    return maps.map((map) => SalaryPayment.fromMap(map)).toList();
  }
}
