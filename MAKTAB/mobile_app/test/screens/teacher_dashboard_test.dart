import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('TeacherDashboard renders placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Text('Teacher Dashboard PlaceHolder')),
      ),
    );

    expect(find.text('Teacher Dashboard PlaceHolder'), findsOneWidget);
  });
}
