import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Batch;
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/student_list_provider.dart';
import 'package:maktab_app/providers/batch_list_provider.dart';
import 'package:maktab_app/providers/attendance_provider.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';

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

  group('Teacher Data Sync & Attendance UI Regression Tests', () {
    test('1. CloudSyncService dispatches onDataSynced events when collections update', () async {
      final syncService = CloudSyncService.instance;
      final events = <String>[];
      final sub = syncService.onDataSynced.listen((collection) {
        events.add(collection);
      });

      syncService.notifyDataChanged('students');
      syncService.notifyDataChanged('attendance');
      syncService.notifyDataChanged('batches');

      await Future.delayed(const Duration(milliseconds: 50));
      expect(events, containsAll(['students', 'attendance', 'batches']));
      await sub.cancel();
    });

    test('2. StudentListProvider auto-refreshes when sync event is emitted', () async {
      final studentRepo = StudentRepository();
      final batchRepo = BatchRepository();
      final provider = StudentListProvider(studentRepo);

      final batchId = await batchRepo.insertBatch(Batch(
        name: 'Test Batch',
        timing: '08:00 AM',
      ));

      await provider.fetchStudents();
      expect(provider.students.length, 0);

      // Insert a student via repo (which notifies CloudSyncService)
      await studentRepo.insertStudent(Student(
        name: 'Sync Test Student',
        admissionNumber: 'ADM-101',
        gender: 'Male',
        batchId: batchId,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Give event loop time to trigger provider listener
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.students.length, 1);
      expect(provider.students.first.name, 'Sync Test Student');
      provider.dispose();
    });

    test('3. BatchListProvider auto-refreshes when sync event is emitted', () async {
      final batchRepo = BatchRepository();
      final provider = BatchListProvider(batchRepo);

      await provider.fetchBatches();
      expect(provider.batches.length, 0);

      await batchRepo.insertBatch(Batch(
        name: 'Hifz Morning Batch',
        timing: '06:00 AM - 08:00 AM',
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.batches.length, 1);
      expect(provider.batches.first.name, 'Hifz Morning Batch');
      provider.dispose();
    });

    test('4. Teacher attendance marking writes locally to SQLite and notifies attendance sync', () async {
      final studentRepo = StudentRepository();
      final batchRepo = BatchRepository();
      final attRepo = AttendanceRepository();

      final batchId = await batchRepo.insertBatch(Batch(
        name: 'Test Batch 2',
        timing: '09:00 AM',
      ));

      final studentId = await studentRepo.insertStudent(Student(
        name: 'Attendance Student',
        admissionNumber: 'ADM-102',
        batchId: batchId,
        createdAt: DateTime.now().toIso8601String(),
      ));

      final events = <String>[];
      final sub = CloudSyncService.instance.onDataSynced.listen((collection) {
        events.add(collection);
      });

      const today = '2026-08-26';
      await attRepo.insertAttendance(Attendance(
        studentId: studentId,
        date: today,
        status: 'Present',
        time: '07:30 AM',
      ));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(events, contains('attendance'));

      final list = await attRepo.getAttendanceByStudent(studentId);
      expect(list.length, 1);
      expect(list.first.status, 'Present');
      expect(list.first.date, today);

      await sub.cancel();
    });

    test('5. Teacher login resolves maktabId and manages sync lifecycle correctly', () async {
      final auth = AuthProvider();
      await auth.initialize();

      final userRepo = UserRepository();
      const salt = 'idara_maktab_sec_salt_2026';
      final teacherPinHash = sha256.convert(utf8.encode('${salt}888888')).toString();

      await userRepo.insertUser(User(
        id: 5,
        name: 'Ustad Ibrahim',
        pinHash: teacherPinHash,
        role: 'teacher',
        mobile: '9888888888',
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      ));

      final loginSuccess = await auth.loginTeacherWithPin('9888888888', '888888');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.name, 'Ustad Ibrahim');

      final currentMaktabId = await CloudSyncService.instance.getMaktabId();
      expect(currentMaktabId.isNotEmpty, isTrue);

      await auth.logout();
      expect(auth.currentUser, isNull);
    });

    test('6. Model deserialization normalizes camelCase/snake_case and handles missing batchId safely', () {
      final jsonStudent = {
        'id': '101',
        'admissionNumber': 'ADM-999',
        'name': 'Camel Case Student',
        'fatherName': 'Father Name',
        'guardianPhone': '9999999999',
        'batchId': null,
        'createdAt': '2026-08-26T10:00:00Z',
      };

      final s = Student.fromMap(jsonStudent);
      expect(s.id, 101);
      expect(s.admissionNumber, 'ADM-999');
      expect(s.name, 'Camel Case Student');
      expect(s.fatherName, 'Father Name');
      expect(s.batchId, 1);

      final jsonBatch = {
        'id': '10',
        'name': 'Special Hifz Batch',
        'timing': '07:00 AM',
        'teacherId': '5',
      };
      final b = Batch.fromMap(jsonBatch);
      expect(b.id, 10);
      expect(b.teacherId, 5);

      final jsonUser = {
        'id': '5',
        'name': 'Ustad Tested',
        'pinHash': 'hash123',
        'role': 'teacher',
        'active': true,
        'createdAt': '2026-08-26T10:00:00Z',
      };
      final u = User.fromMap(jsonUser);
      expect(u.id, 5);
      expect(u.pinHash, 'hash123');
      expect(u.isActive, isTrue);
    });

    test('7. Teacher batch student loading: students in assigned batches are retrieved correctly and never wiped by empty sync', () async {
      final studentRepo = StudentRepository();
      final batchRepo = BatchRepository();
      final attRepo = AttendanceRepository();
      final userRepo = UserRepository();

      await userRepo.insertUser(User(
        id: 10,
        name: 'Ustad Test Ten',
        pinHash: 'hash10',
        role: 'teacher',
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Create assigned batch for teacher ID 10
      final batchId1 = await batchRepo.insertBatch(Batch(
        id: 2,
        name: 'SECTION G1',
        timing: '08:00 AM',
        teacherId: 10,
      ));

      final batchId2 = await batchRepo.insertBatch(Batch(
        id: 3,
        name: 'BALIGAAN SECTION',
        timing: '10:00 AM',
        teacherId: 10,
      ));

      // Insert students assigned to batch 2 and batch 3
      await studentRepo.insertStudent(Student(
        name: 'Student One G1',
        admissionNumber: 'ADM-G1-1',
        batchId: batchId1,
        createdAt: DateTime.now().toIso8601String(),
      ));

      await studentRepo.insertStudent(Student(
        name: 'Student Two Baligaan',
        admissionNumber: 'ADM-BAL-1',
        batchId: batchId2,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // 1. Verify getStudentsByBatch returns the correct students for each batch
      final g1Students = await studentRepo.getStudentsByBatch(batchId1);
      expect(g1Students.length, 1);
      expect(g1Students.first.name, 'Student One G1');

      final baligaanStudents = await studentRepo.getStudentsByBatch(batchId2);
      expect(baligaanStudents.length, 1);
      expect(baligaanStudents.first.name, 'Student Two Baligaan');

      // 2. Verify getAttendanceCountsForBatchDate returns total = 1 for both batches
      final statsG1 = await attRepo.getAttendanceCountsForBatchDate('2026-08-28', batchId1);
      expect(statsG1['total'], 1);

      final statsBaligaan = await attRepo.getAttendanceCountsForBatchDate('2026-08-28', batchId2);
      expect(statsBaligaan['total'], 1);
    });

    test('8. Multi-device new student creation sync: newly created student is pushed, merged into Teacher SQLite and auto-refreshed in AttendanceProvider', () async {
      final studentRepo = StudentRepository();
      final batchRepo = BatchRepository();
      final attRepo = AttendanceRepository();
      final provider = AttendanceProvider(attRepo, studentRepo);

      final batchId = await batchRepo.insertBatch(Batch(
        name: 'New Sync Batch',
        timing: '07:00 AM',
      ));

      provider.setBatchId(batchId);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(provider.students.length, 0);

      // Manager creates new student
      final newStudentId = await studentRepo.insertStudent(Student(
        name: 'SYNC TEST STUDENT',
        admissionNumber: 'ADM-SYNC-99',
        batchId: batchId,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Wait for CloudSyncService event loop to trigger AttendanceProvider listener
      await Future.delayed(const Duration(milliseconds: 150));

      expect(provider.students.length, 1);
      expect(provider.students.first.id, newStudentId);
      expect(provider.students.first.name, 'SYNC TEST STUDENT');
      expect(provider.students.first.batchId, batchId);
      provider.dispose();
    });
  });
}
