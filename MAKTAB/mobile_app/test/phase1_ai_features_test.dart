import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/analytics_service.dart';
import 'package:maktab_app/utils/voice_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Phase 1 AI Features Unit Tests — VoiceParser', () {
    final List<Student> students = [
      Student(id: 1, admissionNumber: 'A1', name: 'Shaik Mohammad Ahmed', dob: '2015-01-01', gender: 'Male', fatherName: 'Father', phone: '123', createdAt: '2026-08-01'),
      Student(id: 2, admissionNumber: 'A2', name: 'Syed Zaid Khan', dob: '2015-01-01', gender: 'Male', fatherName: 'Father', phone: '123', createdAt: '2026-08-01'),
      Student(id: 3, admissionNumber: 'A3', name: 'Fatima Begum', dob: '2015-01-01', gender: 'Female', fatherName: 'Father', phone: '123', createdAt: '2026-08-01'),
    ];

    test('1. VoiceParser detects bulk commands "all present"', () {
      final res = VoiceParser.parseAttendanceVoiceInput('mark all present', students);
      expect(res.studentStatuses[1], 'Present');
      expect(res.studentStatuses[2], 'Present');
      expect(res.studentStatuses[3], 'Present');
    });

    test('2. VoiceParser detects bulk commands "sab absent"', () {
      final res = VoiceParser.parseAttendanceVoiceInput('sab absent', students);
      expect(res.studentStatuses[1], 'Absent');
      expect(res.studentStatuses[2], 'Absent');
      expect(res.studentStatuses[3], 'Absent');
    });

    test('3. VoiceParser matches individual student names and statuses', () {
      final res = VoiceParser.parseAttendanceVoiceInput('Ahmed absent, Zaid late, Fatima present', students);
      expect(res.studentStatuses[1], 'Absent');
      expect(res.studentStatuses[2], 'Late');
      expect(res.studentStatuses[3], 'Present');
    });

    test('4. VoiceParser handles transliterated Urdu/Arabic phrases', () {
      final res = VoiceParser.parseAttendanceVoiceInput('Ahmed gair haazir, Zaid haazir', students);
      expect(res.studentStatuses[1], 'Absent');
      expect(res.studentStatuses[2], 'Present');
    });

    test('5. VoiceParser returns empty map gracefully for empty or un-matched text', () {
      final res = VoiceParser.parseAttendanceVoiceInput('Unknown text without student names', students);
      expect(res.studentStatuses.isEmpty, isTrue);
    });
  });

  group('Phase 1 AI Features Unit Tests — AnalyticsService Anomaly Engine', () {
    test('6. AnalyticsService detects 3+ consecutive absent anomaly', () async {
      final db = await DatabaseHelper.instance.database;

      // Insert student
      await db.insert('students', {
        'id': 10,
        'admission_number': 'S10',
        'name': 'Abdul Waheed',
        'dob': '2015-01-01',
        'gender': 'Male',
        'father_name': 'Father',
        'phone': '9876543210',
        'batch_id': 1,
        'fees_amount': 500,
        'is_deleted': 0,
        'created_at': '2026-08-01',
      });

      // Insert 3 consecutive absent records
      await db.insert('attendance', {'student_id': 10, 'date': '2026-08-22', 'status': 'Absent'});
      await db.insert('attendance', {'student_id': 10, 'date': '2026-08-21', 'status': 'Absent'});
      await db.insert('attendance', {'student_id': 10, 'date': '2026-08-20', 'status': 'Absent'});

      final alerts = await AnalyticsService.instance.getAttendanceAnomalies();
      expect(alerts.isNotEmpty, isTrue);

      final streakAlert = alerts.firstWhere((a) => a.type == AnomalyType.consecutiveAbsent);
      expect(streakAlert.studentId, 10);
      expect(streakAlert.title, contains('3 Consecutive Absences'));
    });

    test('7. AnalyticsService detects low attendance rate (<75%)', () async {
      final db = await DatabaseHelper.instance.database;

      await db.insert('students', {
        'id': 11,
        'admission_number': 'S11',
        'name': 'Yaqoob Shareef',
        'dob': '2015-01-01',
        'gender': 'Male',
        'father_name': 'Father',
        'phone': '9876543210',
        'batch_id': 1,
        'fees_amount': 500,
        'is_deleted': 0,
        'created_at': '2026-08-01',
      });

      // Insert 10 records: 3 Present, 7 Absent (30% attendance rate)
      for (int i = 1; i <= 3; i++) {
        await db.insert('attendance', {'student_id': 11, 'date': '2026-08-0$i', 'status': 'Present'});
      }
      for (int i = 4; i <= 10; i++) {
        await db.insert('attendance', {'student_id': 11, 'date': '2026-08-$i', 'status': 'Absent'});
      }

      final alerts = await AnalyticsService.instance.getAttendanceAnomalies();
      final lowAttAlert = alerts.firstWhere((a) => a.type == AnomalyType.lowAttendance);
      expect(lowAttAlert.studentId, 11);
      expect(lowAttAlert.severity, AlertSeverity.critical);
    });

    test('8. AnalyticsService detects Quran progress stagnation (>14 days without entry)', () async {
      final db = await DatabaseHelper.instance.database;

      await db.insert('students', {
        'id': 12,
        'admission_number': 'S12',
        'name': 'Mohammed Usama',
        'dob': '2015-01-01',
        'gender': 'Male',
        'father_name': 'Father',
        'phone': '9876543210',
        'batch_id': 1,
        'fees_amount': 500,
        'is_deleted': 0,
        'created_at': '2026-08-01',
      });

      // Insert old Quran progress entry from 25 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 25)).toIso8601String().substring(0, 10);
      await db.insert('quran_progress', {
        'student_id': 12,
        'date': oldDate,
        'surah': 'Surah Yaseen',
        'ayah_from': 1,
        'ayah_to': 10,
        'grade': 'A',
        'remarks': 'Good',
      });

      final alerts = await AnalyticsService.instance.getQuranStagnationAnomalies(maxInactivityDays: 14);
      expect(alerts.isNotEmpty, isTrue);

      final quranAlert = alerts.firstWhere((a) => a.type == AnomalyType.quranStagnation);
      expect(quranAlert.studentId, 12);
      expect(quranAlert.title, contains('Quran Progress Inactive'));
    });
  });
}
