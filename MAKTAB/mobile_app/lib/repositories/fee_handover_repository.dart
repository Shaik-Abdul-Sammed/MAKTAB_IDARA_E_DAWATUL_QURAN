import 'package:maktab_app/models/fee_handover.dart';
import 'package:maktab_app/services/database_helper.dart';

class FeeHandoverRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new fee handover (settlement) record
  Future<int> insertHandover(FeeHandover handover) async {
    final db = await _dbHelper.database;
    final map = handover.toMap();
    map.remove('id');
    final id = await db.insert('fee_handovers', map);
    return id;
  }

  /// Get all handovers made by a specific teacher, sorted newest first
  Future<List<FeeHandover>> getHandoversForTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fee_handovers',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'timestamp DESC, id DESC',
    );
    return maps.map((m) => FeeHandover.fromMap(m)).toList();
  }

  /// Total amount handed over (settled) to manager by teacher
  Future<int> getTotalHandedOver(int teacherId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM fee_handovers WHERE teacher_id = ?',
      [teacherId],
    );
    if (result.isNotEmpty) {
      final val = result.first['total'];
      if (val is num) return val.toInt();
    }
    return 0;
  }

  /// Total student fees collected by this teacher
  Future<int> getTotalCollected(int teacherId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM fee_payments WHERE collected_by = ?',
      [teacherId],
    );
    if (result.isNotEmpty) {
      final val = result.first['total'];
      if (val is num) return val.toInt();
    }
    return 0;
  }

  /// Get payments collected by this teacher with student details
  Future<List<Map<String, dynamic>>> getPaymentsCollectedByTeacher(int teacherId) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        fp.id,
        fp.student_id,
        fp.amount,
        fp.mode,
        fp.timestamp,
        fp.reference,
        fp.notes,
        fp.receipt_sent,
        fp.receipt_sent_at,
        fp.collected_by,
        s.name AS student_name,
        s.admission_number,
        s.phone AS student_phone
      FROM fee_payments fp
      LEFT JOIN students s ON fp.student_id = s.id
      WHERE fp.collected_by = ?
      ORDER BY fp.timestamp DESC, fp.id DESC
    ''', [teacherId]);
  }

  /// Get legacy or unattributed fee payments (collected_by IS NULL)
  Future<List<Map<String, dynamic>>> getUnattributedPayments() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        fp.id,
        fp.student_id,
        fp.amount,
        fp.mode,
        fp.timestamp,
        fp.reference,
        fp.notes,
        fp.receipt_sent,
        fp.receipt_sent_at,
        fp.collected_by,
        s.name AS student_name,
        s.admission_number,
        s.phone AS student_phone
      FROM fee_payments fp
      LEFT JOIN students s ON fp.student_id = s.id
      WHERE fp.collected_by IS NULL
      ORDER BY fp.timestamp DESC, fp.id DESC
    ''');
  }

  /// Get all handovers across all teachers (for manager/admin view)
  Future<List<Map<String, dynamic>>> getAllHandoversWithTeacherNames() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        fh.*,
        u.name AS teacher_name,
        u.mobile AS teacher_mobile
      FROM fee_handovers fh
      LEFT JOIN users u ON fh.teacher_id = u.id
      ORDER BY fh.timestamp DESC, fh.id DESC
    ''');
  }

  /// Mark receipt sent for a handover
  Future<int> markReceiptSent(int handoverId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'fee_handovers',
      {
        'receipt_sent': 1,
        'receipt_sent_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [handoverId],
    );
  }
}
