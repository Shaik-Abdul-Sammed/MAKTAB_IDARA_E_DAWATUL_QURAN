import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:maktab_app/screens/login_screen.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Login Screen Tests', () {
    testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('MAKTAB'), findsOneWidget);
      expect(find.text("Idara-e-Dawatul Qur'an"), findsOneWidget);
      
      // Check for keypad buttons
      for (int i = 0; i <= 9; i++) {
        expect(find.text(i.toString()), findsOneWidget);
      }
      
      expect(find.text('Forgot PIN?'), findsOneWidget);
      expect(find.text('Emergency Restore'), findsOneWidget);
    });

    testWidgets('Forgot PIN dialog opens', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: const LoginScreen(),
          ),
        ),
      );

      // Tap Forgot PIN
      await tester.ensureVisible(find.text('Forgot PIN?'));
      await tester.tap(find.text('Forgot PIN?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot PIN?'), findsWidgets); // title
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reset Admin PIN'), findsOneWidget);
    });
  });
}
