import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:maktab_app/screens/login_screen.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Login Screen Tests', () {
    testWidgets('LoginScreen renders Email and Password fields correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('MAKTAB'), findsOneWidget);
      expect(find.text("Idara-e-Dawatul Qur'an"), findsOneWidget);
      expect(find.text('SELECT LOGGING ROLE'), findsOneWidget);
      expect(find.text('Email Address'), findsWidgets);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('LOGIN AS MANAGER'), findsOneWidget);
    });

    testWidgets('Forgot Password dialog opens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pump();

      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Cancel'), findsWidgets);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });
  });
}
