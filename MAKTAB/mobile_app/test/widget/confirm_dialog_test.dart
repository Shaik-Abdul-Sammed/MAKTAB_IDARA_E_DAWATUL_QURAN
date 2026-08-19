import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/widgets/molecules/confirm_dialog.dart';

void main() {
  group('ConfirmDialog Widget Tests', () {
    testWidgets('renders title and message correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfirmDialog(
            title: 'Delete Student',
            message: 'Are you sure you want to delete this student record?',
          ),
        ),
      );

      expect(find.text('Delete Student'), findsOneWidget);
      expect(find.text('Are you sure you want to delete this student record?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('tapping Cancel pops with false', (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ConfirmDialog(title: 'Test', message: 'Test Msg'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('tapping Confirm pops with true', (WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ConfirmDialog(title: 'Test', message: 'Test Msg'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
