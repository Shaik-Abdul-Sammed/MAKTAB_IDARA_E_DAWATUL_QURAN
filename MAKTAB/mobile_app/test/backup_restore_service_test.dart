import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/services/backup_restore_service.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Backup Restore Service Tests', () {
    test('createBackup creates a valid ZIP file', () async {
      // Ensure DB is initialized
      await DatabaseHelper.instance.database;
      
      final service = BackupRestoreService();
      final backupPath = await service.createBackup();
      
      expect(backupPath, isNotNull);
      final file = File(backupPath!);
      expect(await file.exists(), isTrue);
      
      // Cleanup
      await file.delete();
    });
  });
}
