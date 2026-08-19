import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/batch.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Batch;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Teacher and Administrator Connection Tests', () {
    test('Admin can create a Teacher and assign a Batch', () async {
      final userRepo = UserRepository();
      final batchRepo = BatchRepository();

      // 1. Admin creates a Teacher
      final teacher = User(
        name: 'Test Teacher',
        pinHash: 'hashed_pin',
        role: 'teacher',
        createdAt: DateTime.now().toIso8601String(),
      );
      final teacherId = await userRepo.insertUser(teacher);
      expect(teacherId, isPositive);

      // Verify the teacher exists in the system
      final allTeachers = await userRepo.getAllTeachers();
      expect(allTeachers.length, 1);
      expect(allTeachers.first.name, 'Test Teacher');

      // 2. Admin assigns a batch to the created Teacher
      final batch = Batch(
        name: 'Morning Batch',
        timing: '08:00 AM - 10:00 AM',
        teacherId: teacherId,
      );
      final batchId = await batchRepo.insertBatch(batch);
      expect(batchId, isPositive);

      // 3. Teacher queries their assigned batches
      final teacherBatches = await batchRepo.getBatchesByTeacher(teacherId);
      expect(teacherBatches.length, 1);
      expect(teacherBatches.first.name, 'Morning Batch');
    });

    test('Deleting a Teacher safely unlinks their Batches', () async {
      // Setup DB and repositories
      final db = await DatabaseHelper.instance.database;
      final userRepo = UserRepository();
      final batchRepo = BatchRepository();

      // Create Teacher
      final teacherId = await userRepo.insertUser(User(
        name: 'Doomed Teacher',
        pinHash: 'hash',
        role: 'teacher',
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Assign Batch
      await batchRepo.insertBatch(Batch(
        name: 'Orphan Batch',
        timing: '10:00 AM',
        teacherId: teacherId,
      ));

      // Ensure batch is linked
      var batches = await batchRepo.getBatchesByTeacher(teacherId);
      expect(batches.length, 1);
      final batchId = batches.first.id!;

      // Delete the teacher (assuming an admin deletes them)
      await db.delete('users', where: 'id = ?', whereArgs: [teacherId]);

      // Verify the teacher is gone
      final teachers = await userRepo.getAllTeachers();
      expect(teachers.isEmpty, isTrue);

      // Verify the batch still exists, but its teacher_id is now NULL
      final allBatches = await batchRepo.getAllBatches();
      expect(allBatches.length, 1);
      final orphanBatch = allBatches.firstWhere((b) => b.id == batchId);
      expect(orphanBatch.teacherId, isNull);
    });
  });
}
