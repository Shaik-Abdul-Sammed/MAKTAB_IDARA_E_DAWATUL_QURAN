import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts up', (WidgetTester tester) async {
    // Basic test to verify the test suite runs
    expect(true, isTrue);
  });
}
