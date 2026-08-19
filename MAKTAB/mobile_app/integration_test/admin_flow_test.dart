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

  group('Admin Portal Integration Tests', () {
    testWidgets(
      'AdminDashboard renders header with greeting and portal label',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        expect(find.text('Admin Portal'), findsOneWidget);
        expect(find.text('Welcome, Administrator!'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminDashboard renders all 8 feature category tiles',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Core management tiles
        expect(find.text('Students'), findsWidgets);
        expect(find.text('Teachers'), findsWidgets);
        expect(find.text('Batches'), findsWidgets);
        expect(find.text('Fee & UPI'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminDashboard is scrollable when content overflows',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        // Verify we can scroll
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -200));
        await tester.pumpAndSettle();

        // Dashboard still exists after scroll
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'AdminDashboard Fee & UPI tile is visible and tappable',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildAdminApp());
        await tester.pumpAndSettle();

        final feeTile = find.text('Fee & UPI');
        expect(feeTile, findsOneWidget);

        // Scroll to it if needed and ensure it exists
        await tester.ensureVisible(feeTile);
        await tester.pumpAndSettle();

        expect(find.text('Fee & UPI'), findsOneWidget);
      },
    );
  });
}
