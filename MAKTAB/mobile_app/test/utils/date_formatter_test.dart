import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Date Formatter Tests', () {
    test('formats dates properly', () {
      String formatDate(DateTime date) => "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      final date = DateTime(2023, 10, 5);
      expect(formatDate(date), '2023-10-05');
    });
  });
}
