import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/config/api_config.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/models/quran_progress.dart';
import 'package:maktab_app/models/fee_payment.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' hide Batch;
import 'package:maktab_app/services/database_helper.dart';

/// 100% Free ($0/month) Self-Hosted REST Synchronization Service.
/// Interacts with the Python FastAPI REST Backend (`maktab_backend.db`).
/// Local SQLite (`maktab.db`) remains offline cache & primary storage.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();
  CloudSyncService._init();

  Future<String> get _baseUrl async {
    return await ApiConfig.baseUrl;
  }

  Future<String> getMaktabId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? maktabId = prefs.getString('maktab_id');
      if (maktabId == null || maktabId.isEmpty) {
        final db = await DatabaseHelper.instance.database;
        final adminRows = await db.query('users', where: 'role = ?', whereArgs: ['admin']);
        if (adminRows.isNotEmpty) {
          final mobile = adminRows.first['mobile'] as String?;
          if (mobile != null && mobile.isNotEmpty) {
            maktabId = 'MAKTAB-$mobile';
          } else {
            maktabId = 'MAKTAB-${adminRows.first['id']}';
          }
        } else {
          maktabId = 'MAKTAB-1001';
        }
        await prefs.setString('maktab_id', maktabId);
      }
      return maktabId;
    } catch (_) {
      return 'MAKTAB-DEFAULT';
    }
  }

  Future<void> setMaktabId(String maktabId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('maktab_id', maktabId);
    } catch (_) {}
  }

  // ── Single Entity Push Handlers ──────────────────────────────────────────────

  Future<void> pushUser(User user) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "users": [user.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushUser error: $e');
    }
  }

  Future<void> pushBatch(Batch batch) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "batches": [batch.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushBatch error: $e');
    }
  }

  Future<void> pushStudent(Student student) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "students": [student.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushStudent error: $e');
    }
  }

  Future<void> pushAttendance(Attendance attendance) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "attendance": [attendance.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushAttendance error: $e');
    }
  }

  Future<void> pushTeacherAttendance(TeacherAttendance attendance) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "teacher_attendance": [attendance.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushTeacherAttendance error: $e');
    }
  }

  Future<void> pushQuranProgress(QuranProgress progress) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "quran_progress": [progress.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushQuranProgress error: $e');
    }
  }

  Future<void> pushFeePayment(FeePayment payment) async {
    try {
      final maktabId = await getMaktabId();
      final url = await _baseUrl;
      final payload = {
        "maktab_id": maktabId,
        "fee_payments": [payment.toMap()]
      };
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('RestSync pushFeePayment error: $e');
    }
  }

  Future<void> deleteStudentCloud(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final studentRows = await db.query('students', where: 'id = ?', whereArgs: [id]);
      if (studentRows.isNotEmpty) {
        final sMap = Map<String, dynamic>.from(studentRows.first);
        sMap['is_deleted'] = 1;
        sMap['deleted_at'] = DateTime.now().toIso8601String();
        await pushStudent(Student.fromMap(sMap));
      }
    } catch (e) {
      debugPrint('RestSync deleteStudent error: $e');
    }
  }

  Future<void> deleteBatchCloud(int id) async {
    try {
      // Soft deletion notification to backend
    } catch (e) {
      debugPrint('RestSync deleteBatch error: $e');
    }
  }

  // ── Multi-Device Teacher Authentication via REST API ───────────────────────

  Future<User?> authenticateTeacherCloud(String pinHash) async {
    try {
      final url = await _baseUrl;
      final resp = await http.post(
        Uri.parse('$url/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin_hash': pinHash}),
      ).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && data['user'] != null) {
          final userMap = Map<String, dynamic>.from(data['user']);
          final maktabId = data['maktab_id'] ?? 'MAKTAB-1001';
          await setMaktabId(maktabId);

          final user = User.fromMap(userMap);
          final db = await DatabaseHelper.instance.database;
          await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

          await pullAllDataForMaktab(maktabId);
          return user;
        }
      }
    } catch (e) {
      debugPrint('RestSync authenticateTeacherCloud error: $e');
    }
    return null;
  }

  // ── Full Pull & Push Synchronization ───────────────────────────────────────

  Future<bool> pullAllDataForMaktab(String maktabId) async {
    try {
      final url = await _baseUrl;
      final resp = await http.get(Uri.parse('$url/api/v1/sync/pull/$maktabId'))
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final db = await DatabaseHelper.instance.database;

        // Upsert Users
        final users = data['users'] as List?;
        for (var u in users ?? []) {
          final uMap = Map<String, dynamic>.from(u);
          await db.insert('users', uMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Upsert Batches
        final batches = data['batches'] as List?;
        for (var b in batches ?? []) {
          final bMap = Map<String, dynamic>.from(b);
          await db.insert('batches', bMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Upsert Students
        final students = data['students'] as List?;
        for (var s in students ?? []) {
          final sMap = Map<String, dynamic>.from(s);
          await db.insert('students', sMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Upsert Attendance
        final attendance = data['attendance'] as List?;
        for (var a in attendance ?? []) {
          final aMap = Map<String, dynamic>.from(a);
          await db.insert('attendance', aMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Upsert Teacher Attendance
        final teacherAtt = data['teacher_attendance'] as List?;
        for (var ta in teacherAtt ?? []) {
          final taMap = Map<String, dynamic>.from(ta);
          await db.insert('teacher_attendance', taMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Upsert Quran Progress
        final quran = data['quran_progress'] as List?;
        for (var qp in quran ?? []) {
          final qpMap = Map<String, dynamic>.from(qp);
          await db.insert('quran_progress', qpMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Upsert Fee Payments
        final fees = data['fee_payments'] as List?;
        for (var f in fees ?? []) {
          final fMap = Map<String, dynamic>.from(f);
          await db.insert('fee_payments', fMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        return true;
      }
    } catch (e) {
      debugPrint('RestSync pullAllDataForMaktab error: $e');
    }
    return false;
  }

  /// Pushes ALL local Manager/Teacher records to backend, then pulls latest data.
  Future<void> syncAll() async {
    try {
      final maktabId = await getMaktabId();
      final db = await DatabaseHelper.instance.database;

      final users = await db.query('users');
      final batches = await db.query('batches');
      final students = await db.query('students');
      final attendance = await db.query('attendance');
      final teacherAtt = await db.query('teacher_attendance');
      final quran = await db.query('quran_progress');
      final fees = await db.query('fee_payments');

      final payload = {
        "maktab_id": maktabId,
        "users": users,
        "batches": batches,
        "students": students,
        "attendance": attendance,
        "teacher_attendance": teacherAtt,
        "quran_progress": quran,
        "fee_payments": fees
      };

      final url = await _baseUrl;
      await http.post(
        Uri.parse('$url/api/v1/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      await pullAllDataForMaktab(maktabId);
    } catch (e) {
      debugPrint('RestSync syncAll error: $e');
    }
  }
}
