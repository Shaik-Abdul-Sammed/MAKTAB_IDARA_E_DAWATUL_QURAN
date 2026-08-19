import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:maktab_app/widgets/shimmer_loader.dart';

void main() {
  testWidgets('ShimmerLoader renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShimmerListLoader(),
        ),
      ),
    );

    expect(find.byType(ShimmerListLoader), findsOneWidget);
  });
}
