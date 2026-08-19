import 'package:flutter/foundation.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/services/database_helper.dart';

/// One-time safe & idempotent data migration helper from local SQLite cache to Firebase Realtime Database.
class FirebaseMigrationService {
  static final FirebaseMigrationService instance = FirebaseMigrationService._init();
  FirebaseMigrationService._init();

  Future<Map<String, dynamic>> migrateLocalSQLiteToFirebase() async {
    final report = <String, dynamic>{
      'success': false,
      'studentsCount': 0,
      'teachersCount': 0,
      'batchesCount': 0,
      'attendanceCount': 0,
      'quranCount': 0,
      'feeCount': 0,
    };

    try {
      final db = await DatabaseHelper.instance.database;
      final maktabId = await CloudSyncService.instance.getMaktabId();

      // Read pre-migration counts
      report['studentsCount'] = (await db.query('students')).length;
      report['teachersCount'] = (await db.query('users')).length;
      report['batchesCount'] = (await db.query('batches')).length;
      report['attendanceCount'] = (await db.query('attendance')).length;
      report['quranCount'] = (await db.query('quran_progress')).length;
      report['feeCount'] = (await db.query('fee_payments')).length;

      debugPrint('Pre-migration report for $maktabId: $report');

      final success = await CloudSyncService.instance.syncAll();
      report['success'] = success;

      debugPrint('Migration complete for $maktabId: $report');
    } catch (e) {
      debugPrint('Firebase migration error: $e');
      report['error'] = e.toString();
    }
    return report;
  }
}
