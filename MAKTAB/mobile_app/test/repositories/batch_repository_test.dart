import 'package:maktab_app/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/batch.dart' as model;
import 'package:maktab_app/repositories/batch_repository.dart';
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

  group('Batch Repository Tests', () {
    test('insert and retrieve batch', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('users', {'id': 1, 'name': 'Test', 'pin_hash': 'h', 'role': 'teacher', 'created_at': '2023'});
      final repo = BatchRepository();
      final batch = model.Batch(
        name: 'Morning Batch',
        timing: '08:00 AM',
        teacherId: 1,
      );
      
      final id = await repo.insertBatch(batch);
      expect(id, isPositive);
      
      final batches = await repo.getAllBatches();
      expect(batches.length, 1);
      expect(batches.first.name, 'Morning Batch');
    });
  });
}
