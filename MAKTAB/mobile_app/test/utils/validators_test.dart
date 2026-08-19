import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators Tests', () {
    test('validates PIN correctly', () {
      bool isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
      
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('12345'), isFalse);
      expect(isValidPin('abcd'), isFalse);
    });
  });
}
