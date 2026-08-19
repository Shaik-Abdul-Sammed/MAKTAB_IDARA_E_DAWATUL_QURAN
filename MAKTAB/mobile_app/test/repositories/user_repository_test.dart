import 'package:maktab_app/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/repositories/user_repository.dart';
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

  group('User Repository Tests', () {
    test('insert and retrieve user', () async {
      final repo = UserRepository();
      final user = User(
        name: 'Test Teacher',
        pinHash: 'hash',
        role: 'teacher',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      final id = await repo.insertUser(user);
      expect(id, isPositive);
      
      final teachers = await repo.getAllTeachers();
      expect(teachers.length, 1);
      expect(teachers.first.name, 'Test Teacher');
    });
  });
}
