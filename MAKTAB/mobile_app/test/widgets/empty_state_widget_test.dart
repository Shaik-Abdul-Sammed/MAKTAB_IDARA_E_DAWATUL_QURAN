import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:maktab_app/widgets/empty_state_widget.dart';

void main() {
  testWidgets('EmptyStateWidget renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.person_off,
            title: 'No Data',
            message: 'There is nothing here.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_off), findsOneWidget);
    expect(find.text('No Data'), findsOneWidget);
    expect(find.text('There is nothing here.'), findsOneWidget);
  });
}
