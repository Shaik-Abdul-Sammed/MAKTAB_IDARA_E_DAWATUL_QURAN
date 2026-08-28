import 'package:maktab_app/services/database_helper.dart';

enum AlertSeverity { critical, warning, info }

enum AnomalyType { consecutiveAbsent, lowAttendance, attendanceDrop, quranStagnation, unsubmittedAttendance }

class AnomalyAlert {
  final String id;
  final AnomalyType type;
  final String title;
  final String subtitle;
  final AlertSeverity severity;
  final int? studentId;
  final String? studentName;
  final String? batchName;
  final String details;
  final String timestamp;

  AnomalyAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.severity,
    this.studentId,
    this.studentName,
    this.batchName,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'severity': severity.name,
      'student_id': studentId,
      'student_name': studentName,
      'batch_name': batchName,
      'details': details,
      'timestamp': timestamp,
    };
  }
}

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._init();
  AnalyticsService._init();
  factory AnalyticsService() => instance;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Fetch all active dashboard anomaly alerts computed 100% on-device from SQLite
  Future<List<AnomalyAlert>> getDashboardAnomalyAlerts() async {
    final List<AnomalyAlert> alerts = [];

    try {
      final attendanceAnomalies = await getAttendanceAnomalies();
      alerts.addAll(attendanceAnomalies);

      final quranAnomalies = await getQuranStagnationAnomalies();
      alerts.addAll(quranAnomalies);
    } catch (e) {
      // Return empty or partial list gracefully if database is uninitialized
    }

    // Sort by severity (critical -> warning -> info)
    alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return alerts;
  }

  /// Evaluates attendance patterns for consecutive absentees, low attendance rate (<75%), and attendance drops
  Future<List<AnomalyAlert>> getAttendanceAnomalies({int days = 30}) async {
    final db = await _dbHelper.database;
    final List<AnomalyAlert> alerts = [];
    final nowStr = DateTime.now().toIso8601String();

    // 1. Fetch active students with batch name
    final List<Map<String, dynamic>> students = await db.rawQuery('''
      SELECT s.id, s.name, s.batch_id, b.name as batch_name
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.id
      WHERE s.is_deleted = 0
    ''');

    for (var s in students) {
      final int studentId = s['id'];
      final String studentName = s['name'] ?? 'Student #$studentId';
      final String batchName = s['batch_name'] ?? 'Unassigned';

      // Fetch recent 30 attendance records for this student sorted by date desc
      final List<Map<String, dynamic>> records = await db.query(
        'attendance',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'date DESC',
        limit: 30,
      );

      if (records.isEmpty) continue;

      // Check Consecutive Absents (3 or more consecutive absent status at top of list)
      int consecutiveAbsent = 0;
      for (var r in records) {
        final status = (r['status'] as String? ?? '').toLowerCase();
        if (status == 'absent') {
          consecutiveAbsent++;
        } else {
          break;
        }
      }

      if (consecutiveAbsent >= 3) {
        alerts.add(AnomalyAlert(
          id: 'absent_streak_${studentId}_$consecutiveAbsent',
          type: AnomalyType.consecutiveAbsent,
          title: '$studentName — $consecutiveAbsent Consecutive Absences',
          subtitle: 'Absent for the last $consecutiveAbsent consecutive classes in $batchName',
          severity: consecutiveAbsent >= 5 ? AlertSeverity.critical : AlertSeverity.warning,
          studentId: studentId,
          studentName: studentName,
          batchName: batchName,
          details: 'Student has missed $consecutiveAbsent consecutive classes. Consider contacting guardian.',
          timestamp: nowStr,
        ));
      }

      // Check Monthly Attendance Rate (<75%)
      final totalClasses = records.length;
      if (totalClasses >= 5) {
        final presentClasses = records.where((r) {
          final st = (r['status'] as String? ?? '').toLowerCase();
          return st == 'present' || st == 'late';
        }).length;

        final double rate = (presentClasses / totalClasses) * 100;
        if (rate < 75.0) {
          alerts.add(AnomalyAlert(
            id: 'low_att_${studentId}_${rate.toInt()}',
            type: AnomalyType.lowAttendance,
            title: '$studentName — Low Attendance (${rate.toStringAsFixed(0)}%)',
            subtitle: 'Attended $presentClasses of $totalClasses classes in last 30 days',
            severity: rate < 60.0 ? AlertSeverity.critical : AlertSeverity.warning,
            studentId: studentId,
            studentName: studentName,
            batchName: batchName,
            details: 'Attendance rate is below the 75% threshold (${rate.toStringAsFixed(1)}%).',
            timestamp: nowStr,
          ));
        }

        // Check Attendance Drop (Compare first 10 recent vs next 10 older)
        if (records.length >= 14) {
          final recent7 = records.take(7);
          final previous7 = records.skip(7).take(7);

          final recentPresent = recent7.where((r) => (r['status'] as String? ?? '').toLowerCase() == 'present').length;
          final prevPresent = previous7.where((r) => (r['status'] as String? ?? '').toLowerCase() == 'present').length;

          final recentRate = (recentPresent / 7.0) * 100;
          final prevRate = (prevPresent / 7.0) * 100;

          if (prevRate >= 70.0 && (prevRate - recentRate) >= 30.0) {
            alerts.add(AnomalyAlert(
              id: 'att_drop_$studentId',
              type: AnomalyType.attendanceDrop,
              title: '$studentName — Sudden Attendance Drop (-${(prevRate - recentRate).toInt()}%)',
              subtitle: 'Attendance dropped from ${prevRate.toInt()}% to ${recentRate.toInt()}%',
              severity: AlertSeverity.critical,
              studentId: studentId,
              studentName: studentName,
              batchName: batchName,
              details: 'Significant drop detected in student attendance rate over recent weeks.',
              timestamp: nowStr,
            ));
          }
        }
      }
    }

    return alerts;
  }

  /// Evaluates Quran progress entries for stagnation (>14 days without entry)
  Future<List<AnomalyAlert>> getQuranStagnationAnomalies({int maxInactivityDays = 14}) async {
    final db = await _dbHelper.database;
    final List<AnomalyAlert> alerts = [];
    final now = DateTime.now();

    final List<Map<String, dynamic>> students = await db.rawQuery('''
      SELECT s.id, s.name, s.batch_id, b.name as batch_name
      FROM students s
      LEFT JOIN batches b ON s.batch_id = b.id
      WHERE s.is_deleted = 0
    ''');

    for (var s in students) {
      final int studentId = s['id'];
      final String studentName = s['name'] ?? 'Student #$studentId';
      final String batchName = s['batch_name'] ?? 'Unassigned';

      final List<Map<String, dynamic>> quranEntries = await db.query(
        'quran_progress',
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'date DESC',
        limit: 1,
      );

      if (quranEntries.isNotEmpty) {
        final lastEntryDateStr = quranEntries.first['date'] as String?;
        if (lastEntryDateStr != null && lastEntryDateStr.isNotEmpty) {
          final lastDate = DateTime.tryParse(lastEntryDateStr);
          if (lastDate != null) {
            final daysDiff = now.difference(lastDate).inDays;
            if (daysDiff >= maxInactivityDays) {
              final surah = quranEntries.first['surah'] ?? 'Sabaq';
              alerts.add(AnomalyAlert(
                id: 'quran_stagnation_${studentId}_$daysDiff',
                type: AnomalyType.quranStagnation,
                title: '$studentName — Quran Progress Inactive ($daysDiff days)',
                subtitle: 'No new progress recorded since $lastEntryDateStr (Last: $surah)',
                severity: daysDiff >= 21 ? AlertSeverity.critical : AlertSeverity.warning,
                studentId: studentId,
                studentName: studentName,
                batchName: batchName,
                details: 'No Quran progress update submitted for $daysDiff days.',
                timestamp: now.toIso8601String(),
              ));
            }
          }
        }
      }
    }

    return alerts;
  }
}
