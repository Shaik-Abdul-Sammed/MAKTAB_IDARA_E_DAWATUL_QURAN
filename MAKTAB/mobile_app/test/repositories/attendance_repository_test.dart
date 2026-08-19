import 'package:maktab_app/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/attendance.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Attendance Repository Tests', () {
    test('insert and check attendance', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('students', {'id': 1, 'admission_number': '1', 'name': 'S1', 'batch_id': 1, 'created_at': '2023'});
      final repo = AttendanceRepository();
      final attendance = Attendance(
        studentId: 1,
        date: '2023-10-27',
        status: 'present',
      );
      
      final id = await repo.insertAttendance(attendance);
      expect(id, isPositive);
    });
  });
}
