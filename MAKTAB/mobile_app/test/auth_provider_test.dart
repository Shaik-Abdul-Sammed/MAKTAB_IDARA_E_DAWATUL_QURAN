import 'package:flutter_test/flutter_test.dart';
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
  });
}
