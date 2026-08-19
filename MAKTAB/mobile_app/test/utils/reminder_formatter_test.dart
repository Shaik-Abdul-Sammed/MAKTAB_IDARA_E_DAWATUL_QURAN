import 'package:flutter_test/flutter_test.dart';
import 'package:maktab_app/utils/reminder_formatter.dart';

void main() {
  group('ReminderFormatter Tests', () {
    test('formats fee reminder correctly', () {
      final message = ReminderFormatter.formatFeeReminder(
        amountDue: 500.0,
        studentName: 'Ali Khan',
        admissionNumber: 'M-2023-04',
        dueDate: '10th Oct',
      );

      expect(
        message,
        'Assalamu Alaikum, this is a reminder from MAKTAB IDARA E DAWATUL QURAN regarding monthly fee of ₹500 for student Ali Khan (ADM: M-2023-04). Due Date: 10th Oct. JazakAllah Khair.',
      );
    });

    test('formats fee reminder with decimal amounts correctly as int', () {
      final message = ReminderFormatter.formatFeeReminder(
        amountDue: 500.75, // Should become 500
        studentName: 'Zayd',
        admissionNumber: 'A-12',
        dueDate: '15th',
      );

      expect(
        message.contains('₹500'),
        isTrue,
        reason: 'Should cast toInt() when formatting amount',
      );
    });
  });
}
