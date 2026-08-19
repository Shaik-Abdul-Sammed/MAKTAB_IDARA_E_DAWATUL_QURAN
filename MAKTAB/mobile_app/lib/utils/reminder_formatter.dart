class ReminderFormatter {
  static String formatFeeReminder({
    required double amountDue,
    required String studentName,
    required String admissionNumber,
    required String dueDate,
  }) {
    return 'Assalamu Alaikum, this is a reminder from MAKTAB IDARA E DAWATUL QURAN regarding monthly fee of ₹${amountDue.toInt()} for student $studentName (ADM: $admissionNumber). Due Date: $dueDate. JazakAllah Khair.';
  }
}
