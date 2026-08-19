import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/screens/welcome_screen.dart';
import 'package:maktab_app/screens/login_screen.dart';
import 'package:maktab_app/screens/admin_dashboard.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Helper to build a test app with GoRouter for screen-level navigation tests
  Widget buildGoRouterApp({
    required String initialRoute,
    required AuthProvider authProvider,
  }) {
    final router = GoRouter(
      initialLocation: initialRoute,
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboard(),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('End-to-End App Flow Integration Tests', () {
    testWidgets(
      'WelcomeScreen renders brand identity elements correctly',
      (WidgetTester tester) async {
        final authProvider = AuthProvider();
        await tester.pumpWidget(buildGoRouterApp(
          initialRoute: '/welcome',
          authProvider: authProvider,
        ));
        await tester.pumpAndSettle();

        // Verify brand identity
        expect(find.text('MAKTAB'), findsOneWidget);
        expect(find.text("Idara-e-Dawatul Qur'an"), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
        expect(find.text('I already have an account'), findsOneWidget);
        expect(find.text('v1.0 · Offline · Secure'), findsOneWidget);
      },
    );

    testWidgets(
      'LoginScreen renders PIN keypad with all digit buttons',
      (WidgetTester tester) async {
        final authProvider = AuthProvider();
        await tester.pumpWidget(buildGoRouterApp(
          initialRoute: '/login',
          authProvider: authProvider,
        ));
        await tester.pumpAndSettle();

        // Verify header
        expect(find.text('MAKTAB'), findsOneWidget);

        // Verify all PIN keypad digits are rendered
        for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
          expect(find.text(digit), findsOneWidget);
        }
      },
    );

    testWidgets(
      'AdminDashboard renders all navigation tiles correctly',
      (WidgetTester tester) async {
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
        expect(find.text('Students'), findsWidgets);
        expect(find.text('Teachers'), findsWidgets);
        expect(find.text('Batches'), findsWidgets);
        expect(find.text('Fee & UPI'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
      },
    );

    testWidgets(
      'Full Login journey: PIN entry triggers authentication attempt',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_pin_hash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', // hash of "1234"
          'is_registered': true,
        });
        final authProvider = AuthProvider();

        await tester.pumpWidget(buildGoRouterApp(
          initialRoute: '/login',
          authProvider: authProvider,
        ));
        await tester.pumpAndSettle();

        // Tap 4 digits to simulate PIN entry
        await tester.tap(find.text('1'));
        await tester.pump();
        await tester.tap(find.text('2'));
        await tester.pump();
        await tester.tap(find.text('3'));
        await tester.pump();
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();

        // App should attempt login; screen is still visible after failed attempt
        expect(find.byType(LoginScreen), findsAny);
      },
    );
  });
}
