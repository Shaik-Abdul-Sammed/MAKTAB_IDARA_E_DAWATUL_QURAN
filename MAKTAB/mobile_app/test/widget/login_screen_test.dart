import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/screens/login_screen.dart';
import 'package:maktab_app/providers/auth_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthProvider();
    when(() => mockAuth.isAuthenticated).thenReturn(false);
    when(() => mockAuth.hasRegisteredAdminUser).thenReturn(true);
    when(() => mockAuth.isLoading).thenReturn(false);
  });

  Widget buildTestableWidget(Widget child) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => child,
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const Scaffold(body: Text('Admin Dashboard')),
        ),
        GoRoute(
          path: '/teacher',
          builder: (context, state) => const Scaffold(body: Text('Teacher Dashboard')),
        ),
      ],
    );

    return ChangeNotifierProvider<AuthProvider>.value(
      value: mockAuth,
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: false),
        routerConfig: router,
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders Email + Password login UI header and fields', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));

      expect(find.text('MAKTAB'), findsOneWidget);
      expect(find.text("Idara-e-Dawatul Qur'an"), findsOneWidget);
      expect(find.text('SELECT LOGGING ROLE'), findsOneWidget);
      expect(find.text('Email Address'), findsWidgets);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('entering email and password triggers login attempt', (WidgetTester tester) async {
      final mockUser = User(id: 1, name: 'Test', mobile: 'teacher@example.com', role: 'teacher', pinHash: '', createdAt: DateTime.now().toIso8601String());
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuth.loginWithEmail('teacher@example.com', 'password123')).thenAnswer((_) async => true);

      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));

      await tester.enterText(find.byType(TextFormField).first, 'teacher@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.pump();

      await tester.tap(find.text('LOGIN AS MANAGER'));
      await tester.pump();

      verify(() => mockAuth.loginWithEmail('teacher@example.com', 'password123')).called(1);
    });
  });
}
