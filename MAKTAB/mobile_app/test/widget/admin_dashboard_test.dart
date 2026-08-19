import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/screens/admin_dashboard.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthProvider();
    when(() => mockAuth.isAuthenticated).thenReturn(true);
    when(() => mockAuth.hasRegisteredAdminUser).thenReturn(true);
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('AdminDashboard Widget Tests', () {
    testWidgets('renders Admin Portal title and feature grid tiles', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const AdminDashboard()));
      // Use pump with duration instead of pumpAndSettle:
      // AdminDashboard has repeating AnimationControllers (logo pulse, letter
      // stagger) which never settle — pumpAndSettle would time out.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(); // flush remaining frame

      // Verify key navigation feature grid items are present
      expect(find.text('Students'), findsWidgets);
      expect(find.text('Teachers'), findsWidgets);
      expect(find.text('Batches'), findsWidgets);
    });
  });
}
