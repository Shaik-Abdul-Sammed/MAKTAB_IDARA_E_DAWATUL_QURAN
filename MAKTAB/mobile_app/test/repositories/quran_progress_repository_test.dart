import 'package:maktab_app/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/quran_progress.dart';
import 'package:maktab_app/repositories/quran_progress_repository.dart';
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

  group('Quran Progress Repository Tests', () {
    test('insert and retrieve progress', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('students', {'id': 2, 'admission_number': '2', 'name': 'S2', 'batch_id': 1, 'created_at': '2023'});
      final repo = QuranProgressRepository();
      final progress = QuranProgress(
        studentId: 2,
        date: '2023-10-27',
        surah: 'Al-Baqarah',
        ayahFrom: 1,
        ayahTo: 5,
        grade: 'A',
      );
      
      final id = await repo.insertQuranProgress(progress);
      expect(id, isPositive);
      
      final records = await repo.getProgressByStudent(2);
      expect(records.length, 1);
      expect(records.first.surah, 'Al-Baqarah');
    });
  });
}
