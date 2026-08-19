import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maktab_app/screens/teacher_dashboard.dart';
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

  group('TeacherDashboard Widget Tests', () {
    testWidgets('renders Teacher Portal header and quick action cards', (WidgetTester tester) async {
      // Set larger surface size to ensure lazy-loaded GridView items are in viewport and built
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(const TeacherDashboard()));
      // Use pump with duration instead of pumpAndSettle:
      // TeacherDashboard has repeating AnimationControllers (logo pulse, name
      // stagger) which never settle — pumpAndSettle would time out.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(); // flush remaining frame

      expect(find.text('Teacher Portal'), findsOneWidget);
      expect(find.text('Mark Attendance'), findsOneWidget);
      expect(find.text('Quran Recitation'), findsOneWidget);
      expect(find.text('Messages Inbox'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });
  });
}
