import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/services/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    // Reset DB
    final dbPath = await databaseFactory.getDatabasesPath();
    await DatabaseHelper.instance.close();
    await databaseFactory.deleteDatabase('$dbPath/maktab.db');
  });

  group('Auth Provider Tests', () {
    test('initialize creates default admin', () async {
      final auth = AuthProvider();
      await auth.initialize();
      
      final userRepo = UserRepository();
      final admin = await userRepo.getAdminUser();
      
      expect(admin, isNotNull);
      expect(admin!.role, 'admin');
    });

    test('login with correct PIN works', () async {
      final auth = AuthProvider();
      await auth.initialize();
      
      final success = await auth.login('1234');
      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser!.role, 'admin');
    });

    test('login with wrong PIN fails', () async {
      final auth = AuthProvider();
      await auth.initialize();
      
      final success = await auth.login('0000');
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('resetAdminPin works with correct recovery key', () async {
      final auth = AuthProvider();
      await auth.initialize();
      
      // Register the admin first to set a DOB
      await auth.registerFirstUser(
        name: 'New Admin',
        mobile: '1234567890',
        pin: '1234', // Old PIN
        dob: '1980-01-01',
      );
      
      // Reset PIN to 5678
      final success = await auth.resetAdminPin('5678', '1980-01-01');
      expect(success, isTrue);
      
      // Old PIN should fail
      final oldPinSuccess = await auth.login('1234');
      expect(oldPinSuccess, isFalse);
      
      // New PIN should work
      final newPinSuccess = await auth.login('5678');
      expect(newPinSuccess, isTrue);
      expect(auth.currentUser!.role, 'admin');
    });

    test('resetAdminPin fails with wrong recovery key', () async {
      final auth = AuthProvider();
      await auth.initialize();
      
      // Register the admin first
      await auth.registerFirstUser(
        name: 'New Admin',
        mobile: '1234567890',
        pin: '1234',
        dob: '1980-01-01',
      );
      
      final success = await auth.resetAdminPin('5678', '1999-12-31');
      expect(success, isFalse);
      
      // Old PIN should still work
      final oldPinSuccess = await auth.login('1234');
      expect(oldPinSuccess, isTrue);
    });

    test('registerFirstUser registers admin and updates state', () async {
      final auth = AuthProvider();
      await auth.initialize();

      // Initially, default admin has mobile == null, so hasRegisteredAdminUser is false
      expect(auth.hasRegisteredAdminUser, isFalse);

      final success = await auth.registerFirstUser(
        name: 'New Admin',
        mobile: '1234567890',
        pin: '4321',
        dob: '1980-01-01',
      );
      expect(success, isTrue);
      expect(auth.hasRegisteredAdminUser, isTrue);

      // Verify we can log in with new PIN
      final loginSuccess = await auth.login('4321');
      expect(loginSuccess, isTrue);
      expect(auth.currentUser!.name, 'New Admin');
      expect(auth.currentUser!.mobile, '1234567890');
    });

    test('loginTeacherWithPin works for valid active teacher and rejects inactive or wrong PIN', () async {
      final auth = AuthProvider();
      await auth.initialize();

      final userRepo = UserRepository();
      const salt = 'idara_maktab_sec_salt_2026';
      final teacherPinHash = sha256.convert(utf8.encode('${salt}777777')).toString();

      // Insert a test teacher (id = 2)
      await userRepo.insertUser(User(
        name: 'Shaik Mahaboob',
        pinHash: teacherPinHash,
        role: 'teacher',
        mobile: '9177024433',
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // 1. Valid Teacher ID + 6-digit PIN login
      final success = await auth.loginTeacherWithPin('9177024433', '777777');
      expect(success, isTrue);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.name, 'Shaik Mahaboob');
      expect(auth.currentUser!.role, 'teacher');

      // 2. Wrong PIN fails
      final wrongPinSuccess = await auth.loginTeacherWithPin('9177024433', '999999');
      expect(wrongPinSuccess, isFalse);

      // 3. Deactivated teacher fails
      await userRepo.updateUser(auth.currentUser!.copyWith(isActive: false));
      final inactiveSuccess = await auth.loginTeacherWithPin('9177024433', '777777');
      expect(inactiveSuccess, isFalse);
      expect(auth.lastAuthError, contains('inactive'));
    });

    test('provisionTeacherAuthAccount returns safely when Firebase is unavailable locally', () async {
      final auth = AuthProvider();
      await auth.initialize();

      final provisioned = await auth.provisionTeacherAuthAccount(
        teacherId: 10,
        name: 'Test Teacher',
        rawPin: '123456',
      );
      // In offline/mock test environment without Firebase init, gracefully returns true or false without throwing crash
      expect(provisioned, isA<bool>());
    });

    test('loginWithEmail fails gracefully when Firebase Auth is not initialized locally', () async {
      final auth = AuthProvider();
      await auth.initialize();

      final success = await auth.loginWithEmail('admin@test.com', 'password123');
      expect(success, isFalse);
      expect(auth.lastAuthError, contains('not initialized'));
    });
  });
}
