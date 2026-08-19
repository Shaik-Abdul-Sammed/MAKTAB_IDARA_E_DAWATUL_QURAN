import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/screens/admin_dashboard.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildAdminApp() {
    final authProvider = AuthProvider();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: const MaterialApp(home: AdminDashboard()),
    );
  }

  group('Admin Fee Management & Disaster Recovery Integration Tests', () {
    testWidgets(
      'AdminDashboard renders Fee & UPI and Settings shortcut cards',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        expect(find.text('Admin Portal'), findsOneWidget);
        expect(find.text('Fee & UPI'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'Fee & UPI tile is visible and accessible in the dashboard grid',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        final feeTile = find.text('Fee & UPI');
        await tester.ensureVisible(feeTile);
        await tester.pumpAndSettle();

        expect(feeTile, findsOneWidget);
      },
    );

    testWidgets(
      'Settings tile renders and is accessible in the dashboard',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        final settingsTile = find.text('Settings');
        await tester.ensureVisible(settingsTile);
        await tester.pumpAndSettle();

        expect(settingsTile, findsOneWidget);
      },
    );

    testWidgets(
      'Reports tile is available indicating backup/reporting module presence',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Scroll down to find Reports tile
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -200));
        await tester.pumpAndSettle();

        expect(find.text('Reports'), findsOneWidget);
      },
    );
  });
}
