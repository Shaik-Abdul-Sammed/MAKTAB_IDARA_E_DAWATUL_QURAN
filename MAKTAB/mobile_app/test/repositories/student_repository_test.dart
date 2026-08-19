import 'package:maktab_app/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/student.dart';
import 'package:maktab_app/repositories/student_repository.dart';
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

  group('Student Repository Tests', () {
    test('insert and retrieve student', () async {
      final repo = StudentRepository();
      final student = Student(
        admissionNumber: 'ADM123',
        name: 'John Doe',
        batchId: 1,
        createdAt: DateTime.now().toIso8601String(),
      );
      
      final id = await repo.insertStudent(student);
      expect(id, isPositive);
      
      final students = await repo.getStudentsByBatch(1);
      expect(students.length, 1);
      expect(students.first.name, 'John Doe');
    });
  });
}
