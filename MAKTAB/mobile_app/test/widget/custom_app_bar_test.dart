import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/widgets/molecules/custom_app_bar.dart';

void main() {
  group('CustomAppBar Widget Tests', () {
    testWidgets('renders title and actions correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(
              title: 'Fee Management',
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Fee Management'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });
}
