import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/screens/admin_dashboard.dart';
import 'package:maktab_app/screens/teacher_dashboard.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';

/// Tests offline persistence behavior through SharedPreferences mocking.
/// Validates that screens render correctly when local storage is pre-populated
/// vs. when it is empty (first-launch state).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Persistence Integration Tests', () {
    testWidgets(
      'AdminDashboard renders without network when SharedPreferences is empty',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
            ],
            child: const MaterialApp(home: AdminDashboard()),
          ),
        );
        await tester.pumpAndSettle();

        // Should still render even with empty prefs (offline mode)
        expect(find.text('Admin Portal'), findsOneWidget);
      },
    );

    testWidgets(
      'TeacherDashboard renders without network when SharedPreferences is empty',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
            ],
            child: const MaterialApp(home: TeacherDashboard()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Teacher Portal'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminDashboard renders correctly when registered user prefs are populated',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'is_registered': true,
          'admin_name': 'Test Admin',
          'admin_mobile': '9876543210',
        });
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
            ],
            child: const MaterialApp(home: AdminDashboard()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Admin Portal'), findsOneWidget);
        expect(find.text('Welcome, Administrator!'), findsOneWidget);
      },
    );

    testWidgets(
      'App state is consistent across multiple pumpAndSettle cycles (stability test)',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final authProvider = AuthProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
            ],
            child: const MaterialApp(home: AdminDashboard()),
          ),
        );

        // Run multiple pump cycles to ensure no flicker/instability
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Admin Portal'), findsOneWidget);
      },
    );
  });
}
