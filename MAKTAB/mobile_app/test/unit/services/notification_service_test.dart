import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Unit Tests', () {
    test('singleton returns same instance', () {
      final s1 = NotificationService();
      final s2 = NotificationService();
      expect(identical(s1, s2), isTrue);
    });
  });
}
