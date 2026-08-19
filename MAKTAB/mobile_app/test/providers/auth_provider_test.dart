import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Auth Provider Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });
    
    test('initial state is correct', () async {
      final provider = AuthProvider();
      expect(provider.isLoading, false);
      expect(provider.isAuthenticated, false);
    });
  });
}
